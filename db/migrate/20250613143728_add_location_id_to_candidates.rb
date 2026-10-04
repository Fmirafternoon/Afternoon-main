class AddLocationIdToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_reference :candidates, :location, null: true, foreign_key: true
  end
end
