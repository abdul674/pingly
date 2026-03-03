class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :color, default: "#6B7280"
      t.integer :position
      t.timestamps
    end
  end
end
