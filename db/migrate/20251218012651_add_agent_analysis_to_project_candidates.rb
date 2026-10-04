class AddAgentAnalysisToProjectCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :project_candidates, :agent_analysis, :jsonb, default: {}
    add_column :project_candidates, :pushed_at, :datetime
    add_column :project_candidates, :agent_validated_at, :datetime
  end
end
