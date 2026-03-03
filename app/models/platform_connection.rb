class PlatformConnection < ApplicationRecord
  encrypts :credentials, type: :json

  has_many :sources, dependent: :destroy

  validates :platform, presence: true
  validates :external_team_id, uniqueness: { scope: :platform }, allow_nil: true

  enum :connection_method, { oauth: "oauth", manual: "manual" }

  scope :active, -> { where(active: true) }
  scope :slack, -> { where(platform: "slack") }

  def bot_token
    credentials&.dig("bot_token")
  end
end
