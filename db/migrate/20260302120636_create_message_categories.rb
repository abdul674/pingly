class CreateMessageCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :message_categories do |t|
      t.references :message, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :message_categories, [:message_id, :category_id], unique: true
  end
end
