class User::RefreshAgentsCompletionJob
  include Sidekiq::Job

  sidekiq_options retry: 3, queue: "default"

  def perform
    User.agent.kept.find_each do |agent|
      agent.recalculate_average_completion_percentage!
    rescue => e
      Rails.logger.error "Erreur lors du calcul de complétion moyenne de l'agent #{agent.id}: #{e.message}"
    end
  end
end
