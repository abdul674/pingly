class MessageCategory < ApplicationRecord
  belongs_to :message
  belongs_to :category, counter_cache: :messages_count

  validates :category_id, uniqueness: { scope: :message_id }
end
