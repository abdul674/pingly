# Microsoft Teams Integration Plan

## Context

Pingly currently only supports Slack. The goal is to add Microsoft Teams as the second platform, proving out the multi-platform architecture. The existing Provider pattern (`Providers::Base`) makes this straightforward — Teams will follow the exact same patterns as Slack. No database migrations are needed since the schema already uses flexible string/JSON fields.

## Prerequisites

Before implementation, you need an **Azure AD App Registration**:
1. Go to [Azure Entra admin center](https://entra.microsoft.com/) → App registrations → New
2. Set redirect URI to `http://localhost:3000/oauth/teams/callback` (dev)
3. Create a client secret under "Certificates & secrets"
4. Add API permissions: `Team.ReadBasic.All`, `ChannelMessage.Read.All`, `Chat.Read`, `Chat.ReadBasic`, `User.Read`
5. Grant admin consent for the tenant
6. Run `rails credentials:edit` and add:
   ```yaml
   microsoft_teams:
     client_id: <your-client-id>
     client_secret: <your-client-secret>
   ```

---

## Implementation Steps

### 1. Model: Add Teams scope and token accessors
**File**: `app/models/platform_connection.rb`
- Add `scope :teams, -> { where(platform: "teams") }`
- Add `access_token`, `refresh_token`, `token_expires_at`, `token_expired?` methods
- These read from the encrypted `credentials` JSON, same pattern as existing `bot_token`

### 2. Microsoft Graph API Client
**New file**: `app/services/microsoft_graph/client.rb`
- HTTP wrapper around `https://graph.microsoft.com/v1.0` using Faraday (already in bundle)
- Automatic token refresh before every request (`ensure_valid_token!`)
- Refreshes via `POST https://login.microsoftonline.com/common/oauth2/v2.0/token`
- Convenience methods: `joined_teams`, `team_channels(id)`, `channel_messages(team_id, channel_id)`, `chats`, `chat_messages(chat_id)`, `me`

### 3. Teams Provider
**New file**: `app/services/providers/teams.rb`
- Extends `Providers::Base`, implements all 4 required methods
- `sync_sources`: Creates parent Source (type `"team"`) for each Team, child Sources for channels, plus standalone Sources for chats/DMs — leverages existing `parent_id` tree structure
- `fetch_messages(since:)`: Polls monitored sources via Graph API with `$filter=createdDateTime gt {iso8601}` for incremental fetches
- `normalize`: Strips HTML from `body.content`, converts `<at>` tags to `@Name`, extracts sender from `from.user.displayName`, detects mentions via `mentions` array
- `deep_link`: Generates `https://teams.microsoft.com/l/message/{channelId}/{messageId}?groupId={teamId}&tenantId={tenantId}`
- No separate user lookup needed — Teams includes user info inline with messages

### 4. OAuth Controller
**New file**: `app/controllers/oauth/teams_controller.rb`
- `install`: Redirects to `https://login.microsoftonline.com/common/oauth2/v2.0/authorize` with scopes `Team.ReadBasic.All ChannelMessage.Read.All Chat.Read Chat.ReadBasic User.Read offline_access`
- `callback`: Exchanges auth code for tokens, fetches `/me` and `/organization` for tenant identification, creates `PlatformConnection` with `platform: "teams"`, triggers `TeamsSyncSourcesJob`
- Stores `access_token`, `refresh_token`, `expires_at`, `tenant_id`, `user_id` in encrypted credentials

### 5. Routes
**File**: `config/routes.rb`
- Add `get "teams/callback"` and `get "teams/install"` inside existing `namespace :oauth` block

### 6. Background Jobs
**New files**: `app/jobs/teams_polling_job.rb`, `app/jobs/teams_sync_sources_job.rb`
- Mirror `SlackPollingJob` and `SlackSyncSourcesJob` exactly
- No `TeamsListenerJob` — Teams has no WebSocket API (unlike Slack Socket Mode)

**File**: `config/recurring.yml`
- Add `teams_polling` entry (every 5 minutes)

### 7. View & UI Updates
**Files to modify**:
- `app/views/platform_connections/new.html.erb` — Add Teams OAuth button (purple `#5B5FC7` brand color)
- `app/views/platform_connections/_form.html.erb` — Add `["Microsoft Teams", "teams"]` to platform dropdown
- `app/helpers/application_helper.rb` — Add `when "teams"` case to `platform_icon`, add `platform_name` helper
- `app/views/messages/show.html.erb` — Change "Open in Slack" to `"Open in #{platform_name(...)}"`
- `app/views/messages/_message_card.html.erb` — Same for tooltip text
- `app/views/platform_connections/index.html.erb` — Update empty state text
- `app/views/dashboard/index.html.erb` — Update empty state text
- `app/views/sources/_source_row.html.erb` — Add icon for `source_type == "team"`

### 8. Controller Update
**File**: `app/controllers/platform_connections_controller.rb`
- Update `create` action to dispatch correct sync job based on `platform` (add `when "teams"` case)

### 9. CSP Update
**File**: `config/initializers/content_security_policy.rb`
- Add `https://*.microsoft.com` and `https://*.microsoftonline.com` to `img_src` for future avatar support

---

## Files Summary

**New (5)**: `microsoft_graph/client.rb`, `providers/teams.rb`, `oauth/teams_controller.rb`, `teams_polling_job.rb`, `teams_sync_sources_job.rb`

**Modified (10)**: `platform_connection.rb`, `routes.rb`, `recurring.yml`, `_form.html.erb`, `new.html.erb`, `application_helper.rb`, `show.html.erb`, `_message_card.html.erb`, `platform_connections_controller.rb`, `content_security_policy.rb`

**No migrations needed** — existing schema handles Teams with no changes.

## Verification

1. Run `rails credentials:edit` to add microsoft_teams credentials
2. Start server, visit `/connections/new`, confirm Teams OAuth button appears
3. Click "Connect Microsoft Teams" → complete Azure AD OAuth flow
4. Verify connection created with correct credentials in `/connections`
5. Check channels synced via `PlatformConnection.last.sources.count`
6. Toggle monitoring on a channel, wait for polling job (or trigger manually via `TeamsPollingJob.perform_now`)
7. Verify messages appear on dashboard with correct sender, content, deep links
8. Click "Open in Teams" link and confirm it opens in Teams client
