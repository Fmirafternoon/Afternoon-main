class AddPasswordFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_set_at, :datetime
    add_column :users, :invitation_sent_at, :datetime
    add_column :users, :password_token, :string
  end
end
