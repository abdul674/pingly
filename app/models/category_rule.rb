class CategoryRule < ApplicationRecord
  belongs_to :category

  validates :pattern, presence: true
  validates :match_type, inclusion: { in: %w[keyword regex] }

  def matches?(text)
    return false if text.blank?

    case match_type
    when "keyword"
      text.downcase.include?(pattern.downcase)
    when "regex"
      Regexp.new(pattern, Regexp::IGNORECASE).match?(text)
    end
  rescue RegexpError
    false
  end
end
