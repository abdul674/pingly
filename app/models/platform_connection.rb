class PlatformConnection < ApplicationRecord
  encrypts :credentials, type: :json

  has_many :sources, dependent: :destroy

  validates :platform, presence: true
  validates :external_team_id, uniqueness: { scope: :platform }, allow_nil: true

  enum :connection_method, { oauth: "oauth", manual: "manual" }

  scope :active, -> { where(active: true) }
  scope :slack, -> { where(platform: "slack") }
  scope :gmail, -> { where(platform: "gmail") }

  def bot_token
    credentials&.dig("bot_token")
  end

  def access_token
    credentials&.dig("access_token")
  end

  def refresh_token
    credentials&.dig("refresh_token")
  end

  def token_expires_at
    raw = credentials&.dig("expires_at")
    raw ? Time.at(raw.to_i) : nil
  end

  def token_expired?
    token_expires_at.nil? || token_expires_at < 5.minutes.from_now
  end
end
