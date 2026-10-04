class  Resume::UpdateCandidate < Actor
  input :candidate
  input :json_output

  def call
    ActiveRecord::Base.transaction do
      candidate.update!(
        first_name: json_output["first_name"],
        last_name: json_output["last_name"],
        position: json_output["position"],
        gender: json_output["gender"],
        description: json_output["description"],
        birth_year: json_output["birth_year"],
        email: json_output["email"],
        address: json_output["address"],
        phone_number: json_output["phone_number"],
        total_experience_in_years: json_output["total_experience_in_years"],
        has_driving_license: json_output["has_driving_license"],
        has_a_car: json_output["has_a_car"],
        availability_notice: json_output["availability_notice"],
        contract_type: json_output["contract_type"],
        salary_expectation: json_output["salary_expectation"],
        change_motivations: json_output["change_motivations"],
        ongoing_application: json_output["ongoing_applications"]&.dig("quantité"),
        career_relevance: json_output["career_relevance"],
        last_updated_at: json_output["last_updated_at"]
      )

      # Update sectors
      if json_output["sectors"].present?
        candidate.candidate_sectors.destroy_all
        json_output["sectors"].each do |sector_id|
          candidate.sectors << Sector.find(sector_id)
        end
      end

      # Update skills
      if json_output["skills"].present?
        candidate.candidate_skills.destroy_all
        json_output["skills"].each do |skill_data|
          skill = Skill.create_or_find_by_name(skill_data["label"])

          if skill.present? && skill.semantic.blank?
            skill.update!(semantic: skill_data["semantic"])
          end

          candidate.candidate_skills.create!(
            skill: skill,
            seniority: skill_data["seniority"].presence,
            experience: skill_data["experience"]
          )
        end
      end

      # Update mobilities
      if json_output["candidate_mobilities"].present?
        candidate.candidate_mobilities.destroy_all
        json_output["candidate_mobilities"].each do |mobility|
          location = Location.find_or_create_by!(
            city: mobility["city"],
            zip_code: mobility["zip_code"]
          )
          candidate.candidate_mobilities.create!(location: location)
        end
      end

      # Update languages
      if json_output["languages"].present?
        candidate.candidate_languages.destroy_all
        json_output["languages"].each do |language|
          candidate.candidate_languages.create!(
            code: language["code"],
            level: language["level"]
          )
        end
      end

      # Update employments
      if json_output["employments"].present?
        candidate.employments.destroy_all
        json_output["employments"].each do |employment|
          candidate.employments.create!(
            title: employment["title"],
            company: employment["company"],
            description: employment["description"],
            location: employment["location"],
            from_year: employment.dig("from", "year"),
            from_month: employment.dig("from", "month"),
            to_year: employment.dig("to", "year"),
            to_month: employment.dig("to", "month"),
            duration_in_months: employment["duration_in_months"]
          )
        end
      end

      # Update educations
      if json_output["educations"].present?
        candidate.educations.destroy_all
        json_output["educations"].each do |education|
          candidate.educations.create!(
            title: education["title"],
            issuing_organization: education["issuing_organization"],
            location: education["location"],
            from_year: education.dig("from", "year"),
            from_month: education.dig("from", "month"),
            to_year: education.dig("to", "year"),
            to_month: education.dig("to", "month")
          )
        end
      end

      # Update trainings
      if json_output["trainings"].present?
        candidate.trainings.destroy_all
        json_output["trainings"].each do |training|
          candidate.trainings.create!(
            title: training["description"],
            issuing_organization: training["issuing_organization"],
            year: training["year"]
          )
        end
      end

      # Update referrals
      if json_output["references"].present?
        candidate.referrals.destroy_all
        json_output["references"].each do |reference|
          candidate.referrals.create!(
            first_name: reference["full_name"]&.split(" ")&.first,
            last_name: reference["full_name"]&.split(" ")&.drop(1)&.join(" "),
            phone_number: reference["phone_number"],
            email: reference["email"],
            company: reference["company"],
            position: reference["position"],
            description: reference["description"]
          )
        end
      end

      # Update red flags
      if json_output["red_flags"].present?
        candidate.red_flags.destroy_all
        json_output["red_flags"].each do |slug, red_flag|
          next if red_flag["score"].to_i != 1

          candidate.red_flags.create_with(
            score: red_flag["score"],
            question: red_flag["question"],
            optional: ActiveRecord::Type::Boolean.new.cast(red_flag["optional"])
          ).find_or_create_by!(
            slug: slug
          )
        end
      end

      # Update resume summary
      if json_output["resume_summary"].present?
        candidate.update!(resume_summary: json_output["resume_summary"])
      end
    end

    # Execute après la transaction pour éviter de perdre le job si la transaction rollback
    Resume::EmbedJob.perform_async(candidate.id)
  end
end
