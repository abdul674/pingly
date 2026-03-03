class UnsnoozeMessagesJob < ApplicationJob
  queue_as :default

  def perform
    Message.snoozed.where("snoozed_until <= ?", Time.current).find_each do |message|
      message.unsnooze!
    end
  end
end
