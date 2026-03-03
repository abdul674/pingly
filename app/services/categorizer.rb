class Categorizer
  def categorize!(message)
    matched = false

    Category.unscoped.where.not(name: "Uncategorized").find_each do |category|
      if category.matches?(message.content)
        message.message_categories.find_or_create_by!(category: category)
        matched = true
      end
    end

    unless matched
      uncategorized = Category.unscoped.find_by(name: "Uncategorized")
      message.message_categories.find_or_create_by!(category: uncategorized) if uncategorized
    end
  end

  def self.recategorize_all!
    categorizer = new
    Message.find_each do |message|
      message.message_categories.destroy_all
      categorizer.categorize!(message)
    end
  end
end
