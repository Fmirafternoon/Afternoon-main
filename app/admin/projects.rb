ActiveAdmin.register Project do
  menu priority: 4, label: "Projets"

  actions :index, :show

  config.clear_action_items!

  scope :all, default: true
  scope("Actifs") { |scope| scope.active }
  scope("Brouillons") { |scope| scope.draft }
  scope("Archivés") { |scope| scope.archived }

  filter :customer, as: :select, collection: -> {
    User.customer.order(:last_name).map { |u| ["#{u.full_name} (#{u.company&.name})", u.id] }
  }
  filter :status, as: :select, collection: Project.statuses
  filter :position_name
  filter :created_at

  index download_links: false do
    column :id
    column "Poste" do |project|
      div class: "font-semibold" do
        project.position_name
      end
      div class: "text-gray-500 text-sm" do
        project.contract_type
      end
    end

    column "Client" do |project|
      if project.customer
        div do
          link_to project.customer.full_name,
                  admin_user_path(project.customer)
        end
        div class: "text-gray-500 text-sm" do
          project.customer.company&.name
        end
      end
    end

    column "Status" do |project|
      color = case project.status
              when "draft" then "orange"
              when "active" then "green"
              when "archived" then "gray"
              end
      status_tag project.status, class: "bg-#{color}-100 text-#{color}-800"
    end

    column "Candidats" do |project|
      matched = project.project_candidates.matched.count
      pushed = project.project_candidates.pushed.count
      interested = project.project_candidates.interested.count
      rejected = project.project_candidates.rejected.count

      div class: "text-sm space-y-1" do
        div do
          span "#{matched}", class: "font-semibold"
          span " matchés", class: "text-gray-500"
        end if matched > 0
        div do
          span "#{pushed}", class: "font-semibold text-blue-600"
          span " présentés", class: "text-gray-500"
        end if pushed > 0
        div do
          span "#{interested}", class: "font-semibold text-green-600"
          span " intéressés", class: "text-gray-500"
        end if interested > 0
        div do
          span "#{rejected}", class: "font-semibold text-red-600"
          span " rejetés", class: "text-gray-500"
        end if rejected > 0
        span "—", class: "text-gray-400" if matched == 0 && pushed == 0
      end
    end

    column "Créé le", :created_at do |project|
      l(project.created_at, format: :short)
    end

    actions defaults: false do |project|
      item "Voir", admin_project_path(project), class: "action-item-button"
    end
  end

  show do
    attributes_table do
      row :id
      row :position_name
      row :contract_type
      row :status do |project|
        status_tag project.status
      end
      row :customer do |project|
        if project.customer
          link_to "#{project.customer.full_name} (#{project.customer.company&.name})",
                  admin_user_path(project.customer)
        end
      end
      row :location do |project|
        project.location&.city
      end
      row :min_experience_years
      row :target_salary
      row :desired_availability
      row :description do |project|
        simple_format(project.description) if project.description
      end
      row :created_at
      row :updated_at
    end

    panel "Candidats (#{resource.project_candidates.count})" do
      table_for resource.project_candidates.includes(:candidate).order(created_at: :desc) do
        column "Token" do |pc|
          link_to pc.anonymized_number, admin_project_candidate_path(pc)
        end
        column "Candidat" do |pc|
          "#{pc.candidate.first_name} #{pc.candidate.last_name}"
        end
        column "Status" do |pc|
          color = case pc.status
                  when "matched" then "yellow"
                  when "pushed" then "blue"
                  when "interested" then "green"
                  when "rejected" then "red"
                  else "gray"
                  end
          status_tag pc.status, class: "bg-#{color}-100 text-#{color}-800"
        end
        column "Vu le" do |pc|
          pc.viewed_at ? l(pc.viewed_at, format: :short) : "—"
        end
        column "Intérêt" do |pc|
          pc.interest_expressed_at ? l(pc.interest_expressed_at, format: :short) : "—"
        end
      end
    end
  end

  controller do
    def scoped_collection
      end_of_association_chain.includes(:customer, :project_candidates)
    end
  end
end
