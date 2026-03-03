class Source < ApplicationRecord
  belongs_to :platform_connection
  belongs_to :parent, class_name: "Source", optional: true
  has_many :children, class_name: "Source", foreign_key: :parent_id, dependent: :nullify
  has_many :messages, dependent: :destroy

  validates :external_id, presence: true, uniqueness: { scope: :platform_connection_id }

  scope :monitored, -> { where(monitored: true) }
  scope :roots, -> { where(parent_id: nil) }
end
