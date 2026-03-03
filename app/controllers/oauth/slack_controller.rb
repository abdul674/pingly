module Oauth
  class SlackController < ApplicationController
    def install
      scopes = "channels:history,channels:read,groups:history,groups:read,im:history,im:read,mpim:history,mpim:read,users:read,chat:write"
      client_id = Rails.application.credentials.dig(:slack, :client_id)

      if client_id.blank?
        redirect_to platform_connections_path, alert: "Slack OAuth not configured. Please add slack credentials or use manual token setup."
        return
      end

      redirect_to "https://slack.com/oauth/v2/authorize?client_id=#{client_id}&scope=#{scopes}&redirect_uri=#{callback_url}", allow_other_host: true
    end

    def callback
      code = params[:code]
      error = params[:error]

      if error.present?
        redirect_to platform_connections_path, alert: "Slack authorization was denied: #{error}"
        return
      end

      client_id = Rails.application.credentials.dig(:slack, :client_id)
      client_secret = Rails.application.credentials.dig(:slack, :client_secret)

      response = Slack::Web::Client.new.oauth_v2_access(
        client_id: client_id,
        client_secret: client_secret,
        code: code,
        redirect_uri: callback_url
      )

      connection = PlatformConnection.find_or_initialize_by(
        platform: "slack",
        external_team_id: response["team"]["id"]
      )

      connection.assign_attributes(
        workspace_name: response["team"]["name"],
        connection_method: "oauth",
        credentials: {
          "bot_token" => response["access_token"],
          "bot_user_id" => response["bot_user_id"],
          "team_id" => response["team"]["id"]
        },
        active: true
      )

      if connection.save
        SlackSyncSourcesJob.perform_later(connection.id)
        redirect_to platform_connection_path(connection), notice: "Slack workspace connected! Syncing channels..."
      else
        redirect_to platform_connections_path, alert: "Failed to save connection: #{connection.errors.full_messages.join(', ')}"
      end
    rescue Slack::Web::Api::Errors::SlackError => e
      redirect_to platform_connections_path, alert: "Slack OAuth failed: #{e.message}"
    end

    private

    def callback_url
      oauth_slack_callback_url
    end
  end
end
