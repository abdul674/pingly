class Category < ApplicationRecord
  has_many :category_rules, dependent: :destroy
  has_many :message_categories, dependent: :destroy
  has_many :messages, through: :message_categories

  validates :name, presence: true

  default_scope { order(:position) }

  def matches?(text)
    category_rules.any? { |rule| rule.matches?(text) }
  end
end
