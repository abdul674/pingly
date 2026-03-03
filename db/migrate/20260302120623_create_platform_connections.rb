class CreatePlatformConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_connections do |t|
      t.string :platform, null: false
      t.string :workspace_name
      t.text :credentials
      t.boolean :active, default: true, null: false
      t.string :connection_method, default: "manual", null: false
      t.string :external_team_id
      t.timestamps
    end
    add_index :platform_connections, [:platform, :external_team_id], unique: true
  end
end
