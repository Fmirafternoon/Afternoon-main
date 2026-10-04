class AddBroadcastToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :broadcast_enabled, :boolean, default: false, null: false
    add_column :projects, :last_email_broadcasted_at, :datetime
  end
end
