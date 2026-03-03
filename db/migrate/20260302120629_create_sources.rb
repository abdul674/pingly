class CreateSources < ActiveRecord::Migration[8.0]
  def change
    create_table :sources do |t|
      t.references :platform_connection, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :sources }
      t.string :external_id, null: false
      t.string :name
      t.string :source_type
      t.boolean :monitored, default: true, null: false
      t.jsonb :metadata, default: {}
      t.timestamps
    end
    add_index :sources, [:platform_connection_id, :external_id], unique: true
  end
end
