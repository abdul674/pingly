module Oauth
  class GmailController < ApplicationController
    SCOPES = "https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/userinfo.email"
    AUTH_URI = "https://accounts.google.com/o/oauth2/v2/auth"
    TOKEN_URI = "https://oauth2.googleapis.com/token"

    def install
      client_id = Rails.application.credentials.dig(:google, :client_id)

      if client_id.blank?
        redirect_to platform_connections_path, alert: "Google OAuth not configured. Please add google credentials."
        return
      end

      params = {
        client_id: client_id,
        redirect_uri: oauth_gmail_callback_url,
        response_type: "code",
        scope: SCOPES,
        access_type: "offline",
        prompt: "consent"
      }

      redirect_to "#{AUTH_URI}?#{params.to_query}", allow_other_host: true
    end

    def callback
      error = params[:error]
      if error.present?
        redirect_to platform_connections_path, alert: "Google authorization was denied: #{error}"
        return
      end

      token_data = exchange_code(params[:code])
      profile = fetch_profile(token_data["access_token"])

      connection = PlatformConnection.find_or_initialize_by(
        platform: "gmail",
        external_team_id: profile["emailAddress"]
      )

      connection.assign_attributes(
        workspace_name: profile["emailAddress"],
        connection_method: "oauth",
        credentials: {
          "access_token" => token_data["access_token"],
          "refresh_token" => token_data["refresh_token"],
          "expires_at" => Time.current.to_i + token_data["expires_in"].to_i
        },
        active: true
      )

      if connection.save
        GmailSyncSourcesJob.perform_later(connection.id)
        redirect_to platform_connection_path(connection), notice: "Gmail connected! Syncing labels..."
      else
        redirect_to platform_connections_path, alert: "Failed to save connection: #{connection.errors.full_messages.join(', ')}"
      end
    rescue => e
      redirect_to platform_connections_path, alert: "Gmail OAuth failed: #{e.message}"
    end

    private

    def exchange_code(code)
      response = Faraday.post(TOKEN_URI) do |req|
        req.body = {
          code: code,
          client_id: Rails.application.credentials.dig(:google, :client_id),
          client_secret: Rails.application.credentials.dig(:google, :client_secret),
          redirect_uri: oauth_gmail_callback_url,
          grant_type: "authorization_code"
        }
      end

      data = JSON.parse(response.body)
      raise "Token exchange failed: #{data['error_description'] || data['error']}" unless data["access_token"]
      data
    end

    def fetch_profile(access_token)
      service = Google::Apis::GmailV1::GmailService.new
      service.authorization = Signet::OAuth2::Client.new(access_token: access_token)
      profile = service.get_user_profile("me")
      { "emailAddress" => profile.email_address }
    end
  end
end
