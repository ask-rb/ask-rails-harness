class CreateAskSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :ask_sessions do |t|
      t.string :session_id, null: false
      t.string :model
      t.jsonb :data, default: {}
      t.timestamps
    end

    add_index :ask_sessions, :session_id, unique: true
  end
end
