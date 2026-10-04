class CreateProjectCandidateQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :project_candidate_questions do |t|
      t.references :project_candidate, null: false, foreign_key: true
      t.text :question
      t.text :answer
      t.string :kind

      t.timestamps
    end
  end
end
