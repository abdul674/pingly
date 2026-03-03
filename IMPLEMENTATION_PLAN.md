# Pingly — Implementation Plan & Progress

## Status: Phases 1-8 Complete. Phase 9 (Tests) remaining.

### What's Done
- **Phase 1**: Foundation — Gems, DB Schema (7 migrations), Models (6), Seeds (6 categories)
- **Phase 2**: Provider Pattern — Providers::Base, Providers::Slack, MessageProcessor, Categorizer
- **Phase 3**: Background Jobs — SlackPollingJob, SlackSyncSourcesJob, SlackListenerJob, UnsnoozeMessagesJob, recurring schedule
- **Phase 4**: Action Cable — MessagesChannel, CategoryChannel, solid_cable config, database config
- **Phase 5**: Dashboard UI — Routes (all), Controllers (6), Layout, Sidebar, Flash, Dashboard, Message views, Category CRUD views, Connection CRUD views, Source/channel views
- **Phase 6**: Stimulus Controllers — dismissible, channel_tree, message_actions, nested_form, filters
- **Phase 7**: Slack OAuth — OAuth controller, install/callback flow, updated connection UI
- **Phase 8**: Polish — CSP config (Slack CDN + WS), Active Record Encryption keys in credentials, Slack credential placeholders

### What's Left

---

## Phase 1: Foundation — Gems, DB Schema, Models, Seeds

### 1.1 Fix Gemfile platform issue
Change line 24 from:
```ruby
gem "tzinfo-data", platforms: %i[ windows jruby ]
```
to:
```ruby
gem "tzinfo-data", platforms: %i[ mswin jruby ]
```

### 1.2 Create database
```bash
bin/rails db:create
```

### 1.3 Create 7 migrations (in order)

**Migration 1: create_platform_connections**
```ruby
class CreatePlatformConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_connections do |t|
      t.string :platform, null: false
      t.string :workspace_name
      t.text :credentials
      t.boolean :active, default: true, null: false
      t.string :connection_method, default: "manual", null: false
      t.string :external_team_id
      t.timestamps
    end
    add_index :platform_connections, [:platform, :external_team_id], unique: true
  end
end
```

**Migration 2: create_sources**
```ruby
class CreateSources < ActiveRecord::Migration[8.0]
  def change
    create_table :sources do |t|
      t.references :platform_connection, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :sources }
      t.string :external_id, null: false
      t.string :name
      t.string :source_type
      t.boolean :monitored, default: true, null: false
      t.jsonb :metadata, default: {}
      t.timestamps
    end
    add_index :sources, [:platform_connection_id, :external_id], unique: true
  end
end
```

**Migration 3: create_messages**
```ruby
class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :source, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :sender_name
      t.string :sender_avatar
      t.text :content
      t.boolean :mentioned, default: false
      t.string :deep_link
      t.jsonb :raw_data, default: {}
      t.datetime :received_at
      t.string :status, default: "unread", null: false
      t.datetime :snoozed_until
      t.timestamps
    end
    add_index :messages, [:source_id, :external_id], unique: true
    add_index :messages, :status
    add_index :messages, :received_at
    add_index :messages, :snoozed_until
  end
end
```

**Migration 4: create_categories**
```ruby
class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :color, default: "#6B7280"
      t.integer :position
      t.timestamps
    end
  end
end
```

**Migration 5: create_message_categories**
```ruby
class CreateMessageCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :message_categories do |t|
      t.references :message, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :message_categories, [:message_id, :category_id], unique: true
  end
end
```

**Migration 6: create_category_rules**
```ruby
class CreateCategoryRules < ActiveRecord::Migration[8.0]
  def change
    create_table :category_rules do |t|
      t.references :category, null: false, foreign_key: true
      t.string :pattern, null: false
      t.string :match_type, default: "keyword", null: false
      t.timestamps
    end
  end
end
```

**Migration 7: add_counter_caches**
```ruby
class AddCounterCaches < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :messages_count, :integer, default: 0, null: false
    add_column :sources, :messages_count, :integer, default: 0, null: false
  end
end
```

### 1.4 Create 6 Models

**app/models/platform_connection.rb**
```ruby
class PlatformConnection < ApplicationRecord
  encrypts :credentials, type: :json

  has_many :sources, dependent: :destroy

  validates :platform, presence: true
  validates :external_team_id, uniqueness: { scope: :platform }, allow_nil: true

  enum :connection_method, { oauth: "oauth", manual: "manual" }

  scope :active, -> { where(active: true) }
  scope :slack, -> { where(platform: "slack") }

  def bot_token
    credentials&.dig("bot_token")
  end
end
```

**app/models/source.rb**
```ruby
class Source < ApplicationRecord
  belongs_to :platform_connection
  belongs_to :parent, class_name: "Source", optional: true
  has_many :children, class_name: "Source", foreign_key: :parent_id, dependent: :nullify
  has_many :messages, dependent: :destroy

  validates :external_id, presence: true, uniqueness: { scope: :platform_connection_id }

  scope :monitored, -> { where(monitored: true) }
  scope :roots, -> { where(parent_id: nil) }
end
```

**app/models/message.rb**
```ruby
class Message < ApplicationRecord
  belongs_to :source, counter_cache: true
  has_many :message_categories, dependent: :destroy
  has_many :categories, through: :message_categories

  validates :external_id, presence: true, uniqueness: { scope: :source_id }

  scope :unread, -> { where(status: "unread") }
  scope :read, -> { where(status: "read") }
  scope :done, -> { where(status: "done") }
  scope :snoozed, -> { where(status: "snoozed") }
  scope :active, -> { where(status: %w[unread read]) }
  scope :recent, -> { order(received_at: :desc) }

  after_create_commit :broadcast_message

  def mark_read!
    update!(status: "read")
  end

  def mark_done!
    update!(status: "done")
  end

  def snooze!(until_time)
    update!(status: "snoozed", snoozed_until: until_time)
  end

  def unsnooze!
    update!(status: "unread", snoozed_until: nil)
  end

  def platform_connection
    source.platform_connection
  end

  private

  def broadcast_message
    broadcast_prepend_to "messages", partial: "messages/message_card", locals: { message: self }
    categories.each do |category|
      broadcast_prepend_to "category_#{category.id}", partial: "messages/message_card", locals: { message: self }
    end
  end
end
```

**app/models/category.rb**
```ruby
class Category < ApplicationRecord
  has_many :category_rules, dependent: :destroy
  has_many :message_categories, dependent: :destroy
  has_many :messages, through: :message_categories

  validates :name, presence: true

  default_scope { order(:position) }

  def matches?(text)
    category_rules.any? { |rule| rule.matches?(text) }
  end
end
```

**app/models/message_category.rb**
```ruby
class MessageCategory < ApplicationRecord
  belongs_to :message
  belongs_to :category, counter_cache: :messages_count

  validates :category_id, uniqueness: { scope: :message_id }
end
```

**app/models/category_rule.rb**
```ruby
class CategoryRule < ApplicationRecord
  belongs_to :category

  validates :pattern, presence: true
  validates :match_type, inclusion: { in: %w[keyword regex] }

  def matches?(text)
    return false if text.blank?

    case match_type
    when "keyword"
      text.downcase.include?(pattern.downcase)
    when "regex"
      Regexp.new(pattern, Regexp::IGNORECASE).match?(text)
    end
  rescue RegexpError
    false
  end
end
```

### 1.5 Seed default categories + rules
```ruby
# db/seeds.rb
categories = [
  {
    name: "PR Reviews", color: "#8B5CF6", position: 1,
    rules: ["PR", "pull request", "review", "merge"]
  },
  {
    name: "Client Responses", color: "#F59E0B", position: 2,
    rules: ["client", "response", "reply", "follow up"]
  },
  {
    name: "Urgent", color: "#EF4444", position: 3,
    rules: ["urgent", "ASAP", "emergency"]
  },
  {
    name: "Questions", color: "#3B82F6", position: 4,
    rules: ["?"]
  },
  {
    name: "Action Required", color: "#10B981", position: 5,
    rules: ["please", "can you", "todo"]
  },
  {
    name: "Uncategorized", color: "#6B7280", position: 6,
    rules: []
  }
]

categories.each do |cat_data|
  category = Category.find_or_create_by!(name: cat_data[:name]) do |c|
    c.color = cat_data[:color]
    c.position = cat_data[:position]
  end

  cat_data[:rules].each do |pattern|
    category.category_rules.find_or_create_by!(pattern: pattern, match_type: "keyword")
  end
end
```

Then run: `bin/rails db:migrate && bin/rails db:seed`

---

## Phase 2: Provider Pattern & Core Services

### 2.1 `app/services/providers/base.rb`
Abstract base class with: `fetch_messages(since:)`, `normalize(raw_event)`, `deep_link(msg)`, `sync_sources`

### 2.2 `app/services/providers/slack.rb`
- Uses `Slack::Web::Client` with per-connection bot_token
- `fetch_messages` — iterates monitored sources, calls `conversations.history`, filters by mention
- `normalize` — converts raw Slack event to unified hash
- `sync_sources` — calls `conversations.list`, creates/updates Source records
- `resolve_user` — fetches user info with Rails.cache (1hr TTL)
- `deep_link` — builds `https://workspace.slack.com/archives/CHANNEL/pTIMESTAMP`

### 2.3 `app/services/message_processor.rb`
- `process(normalized_msg)` — finds/creates source, deduplicates by external_id, saves, triggers categorizer

### 2.4 `app/services/categorizer.rb`
- `categorize!(message)` — matches content against all category rules, creates join records, falls back to "Uncategorized"
- `self.recategorize_all!` — re-runs categorization on all messages

---

## Phase 3: Background Jobs

### 3.1 `config/initializers/slack.rb` — Configure slack-ruby-client logger
### 3.2 `SlackPollingJob` (every 5 min) — Fetch messages from all active Slack connections
### 3.3 `SlackSyncSourcesJob` — Sync channels/groups for a connection
### 3.4 `SlackListenerJob` (Socket Mode) — Real-time WebSocket listener
### 3.5 `UnsnoozeMessagesJob` (every 1 min) — Unsnooze past-due messages
### 3.6 Update `config/recurring.yml` — Add polling and unsnooze schedules
### 3.7 Update `Procfile.dev` — Add `jobs: bin/jobs` process

---

## Phase 4: Action Cable & Turbo Streams

### 4.1 Switch `config/cable.yml` dev adapter to `solid_cable`
### 4.2 Add cable database to `config/database.yml` development section
### 4.3 Create Action Cable channels (MessagesChannel, CategoryChannel)
### 4.4 Message model broadcasts (after_create_commit)

---

## Phase 5: Dashboard UI — Routes, Controllers, Views

### 5.1 Routes (root, messages, categories, platform_connections, sources)
### 5.2 Controllers (6 files: Dashboard, Messages, Categories, CategoryRules, PlatformConnections, Sources)
### 5.3 Layout & shared views (sidebar, flash, platform icons)
### 5.4 Dashboard views (index, category columns, unread count)
### 5.5 Message views (message card)
### 5.6 Category management views
### 5.7 Platform connection views
### 5.8 Source views (channel tree)

---

## Phase 6: Stimulus Controllers

### 6.1 `dismissible_controller.js`
### 6.2 `channel_tree_controller.js`
### 6.3 `message_actions_controller.js`
### 6.4 `nested_form_controller.js`
### 6.5 `filters_controller.js`
### 6.6 Delete `hello_controller.js`

---

## Phase 7: Slack OAuth Flow & Multi-Workspace Support

### 7.1 Slack App Configuration (credentials)
### 7.2 OAuth Controller (`oauth/slack_controller.rb`)
### 7.3 OAuth Routes
### 7.4 Updated Connections UI (OAuth + Manual)
### 7.5 Multi-workspace dashboard behavior
### 7.6 Token refresh handling

---

## Phase 8: Polish, Security & Setup Guide

### 8.1 Content Security Policy (Slack CDN + WS)
### 8.2 Verify credentials encryption
### 8.3 In-app Slack Setup Guide (SetupController + view)

---

## Phase 9: Tests

- Fixtures for all models
- Model tests: validations, scopes, matches?, encryption
- Service tests: Categorizer, MessageProcessor (mock Slack API)
- Controller tests: CRUD operations, Turbo Stream responses
