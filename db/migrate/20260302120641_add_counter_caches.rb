class AddCounterCaches < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :messages_count, :integer, default: 0, null: false
    add_column :sources, :messages_count, :integer, default: 0, null: false
  end
end
