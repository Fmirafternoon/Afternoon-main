class MigrateSkillsFromCandidates < ActiveRecord::Migration[8.0]
  def up
    Candidate.reset_column_information

    Candidate.find_each do |candidate|
      next if candidate.skills.blank?

      candidate.skills.each do |skill_name|
        slug = skill_name.parameterize

        skill = Skill.find_or_create_by(slug: slug) do |s|
          s.name = skill_name.strip
        end

        CandidateSkill.find_or_create_by(candidate_id: candidate.id, skill_id: skill.id)
      end
    end

    remove_column :candidates, :skills, :string, array: true, default: []
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
