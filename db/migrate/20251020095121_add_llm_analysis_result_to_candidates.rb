class AddLlmAnalysisResultToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :llm_analysis_result, :jsonb
  end
end
