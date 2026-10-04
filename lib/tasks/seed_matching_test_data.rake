namespace :matching do
  desc "Seed test data for matching feature"
  task seed_test_data: :environment do
    puts "Creating test data for matching..."

    # Locations
    paris = Location.find_or_create_by!(city: "Paris") do |loc|
      loc.address = "Paris, France"
      loc.latitude = 48.8566
      loc.longitude = 2.3522
    end

    lyon = Location.find_or_create_by!(city: "Lyon") do |loc|
      loc.address = "Lyon, France"
      loc.latitude = 45.7640
      loc.longitude = 4.8357
    end

    bordeaux = Location.find_or_create_by!(city: "Bordeaux") do |loc|
      loc.address = "Bordeaux, France"
      loc.latitude = 44.8378
      loc.longitude = -0.5792
    end

    saint_germain = Location.find_or_create_by!(city: "Saint-Germain-du-Puch") do |loc|
      loc.address = "Saint-Germain-du-Puch, France"
      loc.latitude = 44.9167
      loc.longitude = -0.1167
    end

    angers = Location.find_or_create_by!(city: "Angers") do |loc|
      loc.address = "Angers, France"
      loc.latitude = 47.4784
      loc.longitude = -0.5632
    end

    puts "✓ Locations created"

    # Skills
    skills = [
      "Cuisine française",
      "Cuisine gastronomique",
      "Management d'équipe",
      "Service en salle",
      "Sommellerie",
      "Pâtisserie",
      "Vente B2B",
      "Négociation commerciale",
      "Développement Ruby"
    ].map do |name|
      Skill.find_or_create_by!(name: name)
    end

    puts "✓ Skills created"

    # Recruitment office for agents
    office = RecruitmentOffice.find_or_create_by!(name: "Bureau Test") do |o|
      o.address = "123 Rue Test, Paris"
    end

    # Agent user
    agent = User.find_or_create_by!(email: "agent@test.com") do |u|
      u.password = "password123"
      u.password_confirmation = "password123"
      u.first_name = "Agent"
      u.last_name = "Test"
      u.role = :agent_user
      u.recruitment_office = office
    end

    # Customer user
    customer = User.find_or_create_by!(email: "customer@test.com") do |u|
      u.password = "password123"
      u.password_confirmation = "password123"
      u.first_name = "Client"
      u.last_name = "Test"
      u.role = :customer
    end

    puts "✓ Users created"

    # Candidates
    candidates_data = [
      {
        first_name: "Pierre",
        last_name: "Martin",
        position: "Chef de cuisine",
        contract_type: "cdi",
        location: paris,
        skills: ["Cuisine française", "Cuisine gastronomique", "Management d'équipe"],
        languages: ["fr", "en"],
        experience_months: 120 # 10 ans
      },
      {
        first_name: "Marie",
        last_name: "Dubois",
        position: "Sous-chef",
        contract_type: "cdi",
        location: paris,
        skills: ["Cuisine française", "Pâtisserie"],
        languages: ["fr"],
        experience_months: 60 # 5 ans
      },
      {
        first_name: "Jean",
        last_name: "Bernard",
        position: "Chef de partie",
        contract_type: "cdd",
        location: lyon,
        skills: ["Cuisine française"],
        languages: ["fr", "es"],
        experience_months: 36 # 3 ans
      },
      {
        first_name: "Sophie",
        last_name: "Leroy",
        position: "Sommelier",
        contract_type: "cdi",
        location: bordeaux,
        skills: ["Sommellerie", "Service en salle"],
        languages: ["fr", "en", "es"],
        experience_months: 84 # 7 ans
      },
      {
        first_name: "Thomas",
        last_name: "Moreau",
        position: "Ingénieur commercial",
        contract_type: "cdi",
        location: angers,
        skills: ["Vente B2B", "Négociation commerciale"],
        languages: ["fr", "en"],
        experience_months: 48 # 4 ans
      },
      {
        first_name: "Julie",
        last_name: "Petit",
        position: "Serveuse",
        contract_type: "interim",
        location: paris,
        skills: ["Service en salle"],
        languages: ["fr"],
        experience_months: 24 # 2 ans
      },
      {
        first_name: "Lucas",
        last_name: "Garcia",
        position: "Cuisinier",
        contract_type: "cdi",
        location: angers,
        skills: ["Cuisine française"],
        languages: ["fr", "ar"],
        experience_months: 36 # 3 ans
      },
      {
        first_name: "Emma",
        last_name: "Robert",
        position: "Chef pâtissier",
        contract_type: "cdi",
        location: paris,
        skills: ["Pâtisserie", "Cuisine française"],
        languages: ["fr", "de"],
        experience_months: 96 # 8 ans
      }
    ]

    candidates_data.each do |data|
      candidate = Candidate.find_or_initialize_by(
        first_name: data[:first_name],
        last_name: data[:last_name]
      )

      candidate.assign_attributes(
        agent: agent,
        email: "#{data[:first_name].downcase}.#{data[:last_name].downcase}@test.com",
        phone_number: "+33612345678",
        position: data[:position],
        contract_type: data[:contract_type],
        location: data[:location],
        publication_status: "published",
        import_status: "completed",
        birth_year: 1990,
        job_title_embedding: EmbeddingCache.get_embedding(data[:position])
      )

      if candidate.save
        # Mobilities
        candidate.candidate_mobilities.find_or_create_by!(location: data[:location])

        # Skills
        data[:skills].each do |skill_name|
          skill = Skill.find_by(name: skill_name)
          candidate.candidate_skills.find_or_create_by!(skill: skill) if skill
        end

        # Languages
        data[:languages].each do |lang_code|
          candidate.candidate_languages.find_or_create_by!(code: lang_code)
        end

        # Experience
        candidate.employments.find_or_create_by!(
          title: data[:position],
          company: "Restaurant Test",
          from_year: 2015,
          to_year: 2024,
          duration_in_months: data[:experience_months]
        )

        puts "  ✓ Candidate: #{candidate.full_name} (#{data[:position]} - #{data[:location].city})"
      else
        puts "  ✗ Error creating #{data[:first_name]} #{data[:last_name]}: #{candidate.errors.full_messages.join(', ')}"
      end
    end

    puts "\n✓ #{Candidate.published.count} published candidates created"
    puts "\nTest credentials:"
    puts "  Customer: customer@test.com / password123"
    puts "  Agent: agent@test.com / password123"
    puts "\nYou can now create a project and test the matching!"
  end
end
