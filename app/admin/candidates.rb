ActiveAdmin.register Candidate do
  menu priority: 3

  # Désactiver les actions de création, modification et show
  actions :index

  config.clear_action_items!

  # Index avec colonnes personnalisées
  index download_links: false do
    selectable_column
    column "Nom", sortable: false do |candidate|
      div class: "font-semibold" do
        candidate.position
      end
      div class: "flex items-center gap-x-2" do
      "#{candidate.first_name} #{candidate.last_name}"
      end
    end

    column "Statut" do |candidate|
      status_tag candidate.publication_status
    end
    column "créé le", :created_at, sortable: false

    column "par" do |candidate|
      div do
        link_to candidate.agent.full_name, "/admin/users/#{candidate.agent_id}" if candidate.agent
      end
      div class: "flex items-center gap-x-2" do
        link_to candidate.agent&.recruitment_office&.name, "/admin/recruitment_offices/#{candidate.agent&.recruitment_office_id}" if candidate.agent&.recruitment_office
      end
    end
    actions defaults: false do |candidate|
      if candidate.agent
        item "Voir la fiche candidat",
             "/admin/candidates/#{candidate.id}/view_as_agent",
             class: "action-item-button"
      end
    end
  end

  config.filters = false

  # Action personnalisée pour voir la fiche en impersonant l'agent
  member_action :view_as_agent, method: :get do
    candidate = Candidate.find(params[:id])
    # TODO: Réactiver l'authorization - La policy existe (view_as_agent?) mais il y a un problème de cache
    # authorize candidate, :view_as_agent?

    if candidate.agent
      # Stocker l'URL de retour pour le bouton Stop
      session[:impersonation_return_to] = request.referer || admin_candidates_path

      # Impersonate l'agent pour voir sa fiche candidat
      impersonate_user(candidate.agent)
      redirect_to "/agent/candidates/#{candidate.id}",
                  notice: "Vous consultez la fiche en tant que #{candidate.agent.full_name}"
    else
      redirect_to "/admin/candidates",
                  alert: "Ce candidat n'a pas d'agent assigné"
    end
  end

  controller do
    def scoped_collection
      end_of_association_chain.kept
    end
  end
end
