class CreateCategoryRules < ActiveRecord::Migration[8.0]
  def change
    create_table :category_rules do |t|
      t.references :category, null: false, foreign_key: true
      t.string :pattern, null: false
      t.string :match_type, default: "keyword", null: false
      t.timestamps
    end
  end
end
