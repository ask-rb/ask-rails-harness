class CreateAskAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :ask_audit_logs do |t|
      t.string :session_id, null: false
      t.string :tool_name, null: false
      t.jsonb :params
      t.jsonb :result_summary
      t.string :status, null: false, default: "success"
      t.text :error_message
      t.integer :duration_ms
      t.jsonb :user_context
      t.string :environment
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :ask_audit_logs, :session_id
    add_index :ask_audit_logs, [:recorded_at, :tool_name]
    add_index :ask_audit_logs, :status
  end
end
