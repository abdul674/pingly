class SlackSyncSourcesJob < ApplicationJob
  queue_as :default

  def perform(connection_id)
    connection = PlatformConnection.find(connection_id)
    return unless connection.active? && connection.platform == "slack"

    provider = Providers::Slack.new(connection)
    provider.sync_sources
  end
end
