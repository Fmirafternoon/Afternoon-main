class AddOptionalToRedFlags < ActiveRecord::Migration[8.0]
  def change
    add_column :red_flags, :optional, :boolean, default: true
  end
end
