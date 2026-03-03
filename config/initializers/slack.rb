Slack.configure do |config|
  config.token = nil # Per-connection tokens used instead
  config.logger = Rails.logger
end
