class AddEmailAlertsToSavedSearches < ActiveRecord::Migration[8.0]
  def change
    add_column :saved_searches, :email_alerts_enabled, :boolean, default: false, null: false
    add_column :saved_searches, :last_alert_sent_at, :datetime

    add_index :saved_searches, :email_alerts_enabled
    add_index :saved_searches, [:email_alerts_enabled, :last_alert_sent_at]
  end
end
