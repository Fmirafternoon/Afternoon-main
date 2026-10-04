class AddResumeSummaryToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :resume_summary, :jsonb, default: {}
  end
end
