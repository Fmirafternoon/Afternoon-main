class AddVectorExtension < ActiveRecord::Migration[8.0]
  def up
    enable_extension 'vector' unless extension_enabled?('vector')
  end

  def down
    disable_extension 'vector' if extension_enabled?('vector')
  end
end
