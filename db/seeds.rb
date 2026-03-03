categories = [
  {
    name: "PR Reviews", color: "#8B5CF6", position: 1,
    rules: ["PR", "pull request", "review", "merge"]
  },
  {
    name: "Client Responses", color: "#F59E0B", position: 2,
    rules: ["client", "response", "reply", "follow up"]
  },
  {
    name: "Urgent", color: "#EF4444", position: 3,
    rules: ["urgent", "ASAP", "emergency"]
  },
  {
    name: "Questions", color: "#3B82F6", position: 4,
    rules: ["?"]
  },
  {
    name: "Action Required", color: "#10B981", position: 5,
    rules: ["please", "can you", "todo"]
  },
  {
    name: "Uncategorized", color: "#6B7280", position: 6,
    rules: []
  }
]

categories.each do |cat_data|
  category = Category.find_or_create_by!(name: cat_data[:name]) do |c|
    c.color = cat_data[:color]
    c.position = cat_data[:position]
  end

  cat_data[:rules].each do |pattern|
    category.category_rules.find_or_create_by!(pattern: pattern, match_type: "keyword")
  end
end
