class GmailPollingJob < ApplicationJob
  queue_as :default

  def perform
    PlatformConnection.active.gmail.find_each do |connection|
      provider = Providers::Gmail.new(connection)
      since = connection.sources.joins(:messages)
                .maximum("messages.received_at") || 5.minutes.ago
      provider.fetch_messages(since: since)
    rescue => e
      Rails.logger.error "GmailPollingJob error for connection #{connection.id}: #{e.message}"
    end
  end
end
