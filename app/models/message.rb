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
