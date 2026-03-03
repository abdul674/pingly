class SlackPollingJob < ApplicationJob
  queue_as :default

  def perform
    PlatformConnection.active.slack.find_each do |connection|
      provider = Providers::Slack.new(connection)
      since = connection.sources.joins(:messages)
                .maximum("messages.received_at") || 5.minutes.ago
      provider.fetch_messages(since: since)
    rescue => e
      Rails.logger.error "SlackPollingJob error for connection #{connection.id}: #{e.message}"
    end
  end
end
