# Preview all emails at http://localhost:3000/rails/mailers/digest_mailer
class DigestMailerPreview < ActionMailer::Preview
  def weekly_alert
    # Utiliser un customer existant ou créer un objet temporaire
    customer = User.where(role: 'customer').first
    if customer.nil?
      customer = User.new(
        id: 1,
        email: "customer@example.com",
        first_name: "Jean",
        last_name: "Dupont",
        role: "customer"
      )
    end

    # Créer des données de test
    alerts_data = []

    # Première recherche sauvegardée
    saved_search1 = SavedSearch.new(
      id: 1,
      name: "Développeurs Ruby Paris",
      customer_id: customer.id,
      criteria: {
        query: "Ruby",
        city: "Paris",
        skills: ["Ruby on Rails", "PostgreSQL"]
      }
    )

    candidates1 = []
    3.times do |i|
      candidate = Candidate.new(
        first_name: "Jean#{i}",
        last_name: "Dupont#{i}",
        position: "Développeur Ruby Senior",
        total_experience_in_years: 5 + i,
        email: "jean.dupont#{i}@example.com",
        phone_number: "0123456789"
      )

      # Mock les associations
      location = OpenStruct.new(city: "Paris")
      skills = [
        OpenStruct.new(name: "Ruby on Rails"),
        OpenStruct.new(name: "PostgreSQL"),
        OpenStruct.new(name: "Redis")
      ]

      candidate.define_singleton_method(:location) { location }
      candidate.define_singleton_method(:skills) { skills }
      candidate.define_singleton_method(:id) { 100 + i }

      candidates1 << candidate
    end

    alerts_data << {
      search: saved_search1,
      candidates: candidates1,
      total_count: 7
    }

    # Deuxième recherche sauvegardée
    saved_search2 = SavedSearch.new(
      id: 2,
      name: "DevOps Bordeaux",
      customer_id: customer.id,
      criteria: {
        query: "DevOps",
        city: "Bordeaux",
        skills: ["Docker", "Kubernetes"]
      }
    )

    candidates2 = []
    2.times do |i|
      candidate = Candidate.new(
        first_name: "Marie#{i}",
        last_name: "Martin#{i}",
        position: "Ingénieur DevOps",
        total_experience_in_years: 3 + i,
        email: "marie.martin#{i}@example.com",
        phone_number: "0987654321"
      )

      location = OpenStruct.new(city: "Bordeaux")
      skills = [
        OpenStruct.new(name: "Docker"),
        OpenStruct.new(name: "Kubernetes"),
        OpenStruct.new(name: "AWS")
      ]

      candidate.define_singleton_method(:location) { location }
      candidate.define_singleton_method(:skills) { skills }
      candidate.define_singleton_method(:id) { 200 + i }

      candidates2 << candidate
    end

    alerts_data << {
      search: saved_search2,
      candidates: candidates2,
      total_count: 4
    }

    DigestMailer.weekly_alert(
      customer: customer,
      alerts_data: alerts_data
    )
  end
end
