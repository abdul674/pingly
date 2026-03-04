module GoogleAuth
  class Client
    TOKEN_URI = "https://oauth2.googleapis.com/token"

    attr_reader :connection

    def initialize(connection)
      @connection = connection
    end

    def ensure_valid_token!
      return unless connection.token_expired?
      refresh_access_token!
    end

    def refresh_access_token!
      response = Faraday.post(TOKEN_URI) do |req|
        req.body = {
          client_id: Rails.application.credentials.dig(:google, :client_id),
          client_secret: Rails.application.credentials.dig(:google, :client_secret),
          refresh_token: connection.refresh_token,
          grant_type: "refresh_token"
        }
      end

      data = JSON.parse(response.body)

      if data["access_token"]
        connection.update!(
          credentials: connection.credentials.merge(
            "access_token" => data["access_token"],
            "expires_at" => Time.current.to_i + data["expires_in"].to_i
          )
        )
      else
        raise "Failed to refresh Google token: #{data['error_description'] || data['error']}"
      end
    end
  end
end
