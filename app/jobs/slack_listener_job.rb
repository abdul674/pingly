class SlackListenerJob < ApplicationJob
  queue_as :default

  def perform(connection_id)
    connection = PlatformConnection.find(connection_id)
    return unless connection.active? && connection.platform == "slack"

    app_token = connection.credentials&.dig("app_token")
    return unless app_token

    provider = Providers::Slack.new(connection)
    client = Slack::Web::Client.new(token: connection.bot_token)

    # Open a WebSocket connection via Socket Mode
    response = Faraday.post("https://slack.com/api/apps.connections.open") do |req|
      req.headers["Authorization"] = "Bearer #{app_token}"
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
    end

    data = JSON.parse(response.body)
    return unless data["ok"]

    ws_url = data["url"]

    EM.run do
      ws = Faye::WebSocket::Client.new(ws_url)

      ws.on :message do |event|
        payload = JSON.parse(event.data)

        # Acknowledge envelope
        if payload["envelope_id"]
          ws.send({ envelope_id: payload["envelope_id"] }.to_json)
        end

        next unless payload["type"] == "events_api"

        inner = payload.dig("payload", "event")
        next unless inner && inner["type"] == "message" && inner["subtype"].nil?

        source = connection.sources.find_by(external_id: inner["channel"])
        next unless source&.monitored?

        normalized = provider.normalize(inner, source: source, bot_user_id: nil)
        MessageProcessor.new.process(normalized)
      end

      ws.on :close do |_event|
        EM.stop
        # Re-enqueue to reconnect
        SlackListenerJob.set(wait: 5.seconds).perform_later(connection_id) if connection.reload.active?
      end
    end
  rescue => e
    Rails.logger.error "SlackListenerJob error for connection #{connection_id}: #{e.message}"
    SlackListenerJob.set(wait: 30.seconds).perform_later(connection_id)
  end
end
