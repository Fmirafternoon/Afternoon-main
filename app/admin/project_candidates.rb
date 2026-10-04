ActiveAdmin.register ProjectCandidate do
  menu priority: 5, label: "Matching"

  actions :index, :show

  config.clear_action_items!

  scope :all, default: true
  scope("Matchés") { |scope| scope.matched }
  scope("Présentés") { |scope| scope.pushed }
  scope("Intéressés") { |scope| scope.interested }
  scope("Rejetés") { |scope| scope.rejected }

  filter :project, collection: -> {
    Project.active.order(created_at: :desc).map { |p| ["#{p.position_name} - #{p.client_name}", p.id] }
  }
  filter :status, as: :select, collection: ProjectCandidate.statuses
  filter :created_at, label: "Matché le"
  filter :viewed_at, label: "Vu le"
  filter :interest_expressed_at, label: "Intérêt exprimé le"

  index download_links: false do
    column :id

    column "Projet" do |pc|
      div do
        link_to pc.project.position_name, admin_project_path(pc.project)
      end
      div class: "text-gray-500 text-sm" do
        pc.project.client_name
      end
    end

    column "Candidat" do |pc|
      div class: "font-semibold" do
        pc.anonymized_number
      end
      div class: "text-gray-500 text-sm" do
        "#{pc.candidate.first_name} #{pc.candidate.last_name}"
      end
    end

    column "Cabinet" do |pc|
      if pc.candidate.agent&.recruitment_office
        link_to pc.candidate.agent.recruitment_office.name,
                admin_recruitment_office_path(pc.candidate.agent.recruitment_office)
      else
        "—"
      end
    end

    column "Status" do |pc|
      color = case pc.status
              when "pending" then "gray"
              when "matched" then "yellow"
              when "validated" then "indigo"
              when "pushed" then "blue"
              when "interested" then "green"
              when "rejected" then "red"
              when "hired" then "emerald"
              else "gray"
              end
      status_tag pc.status, class: "bg-#{color}-100 text-#{color}-800"
    end

    column "Timeline" do |pc|
      div class: "text-sm space-y-1" do
        div do
          span "Matché: ", class: "text-gray-500"
          span l(pc.created_at, format: :short)
        end
        if pc.pushed? || pc.interested? || pc.rejected?
          div do
            span "Présenté: ", class: "text-gray-500"
            span pc.pushed_at ? l(pc.pushed_at, format: :short) : "—"
          end
        end
        if pc.viewed_at
          div do
            span "Vu: ", class: "text-gray-500"
            span l(pc.viewed_at, format: :short)
          end
        end
        if pc.interest_expressed_at
          div do
            span "Réponse: ", class: "text-gray-500"
            span l(pc.interest_expressed_at, format: :short)
          end
        end
      end
    end

    column "Message client" do |pc|
      if pc.interest_message.present?
        truncate(pc.interest_message, length: 50)
      else
        "—"
      end
    end

    actions defaults: false do |pc|
      item "Voir", admin_project_candidate_path(pc), class: "action-item-button"
    end
  end

  show do
    attributes_table do
      row :id
      row :project do |pc|
        link_to "#{pc.project.position_name} - #{pc.project.client_name}",
                admin_project_path(pc.project)
      end
      row :candidate do |pc|
        div do
          "#{pc.candidate.first_name} #{pc.candidate.last_name} (#{pc.anonymized_number})"
        end
      end
      row :status do |pc|
        status_tag pc.status
      end
      row "Cabinet" do |pc|
        if pc.candidate.agent&.recruitment_office
          link_to pc.candidate.agent.recruitment_office.name,
                  admin_recruitment_office_path(pc.candidate.agent.recruitment_office)
        end
      end
      row "Agent" do |pc|
        if pc.candidate.agent
          link_to pc.candidate.agent.full_name,
                  admin_user_path(pc.candidate.agent)
        end
      end
    end

    panel "Timeline" do
      attributes_table_for resource do
        row "Matché le" do |pc|
          pc.created_at ? l(pc.created_at, format: :long) : "—"
        end
        row "Présenté le" do |pc|
          pc.pushed_at ? l(pc.pushed_at, format: :long) : "—"
        end
        row "Vu le" do |pc|
          pc.viewed_at ? l(pc.viewed_at, format: :long) : "—"
        end
        row "Réponse client le" do |pc|
          pc.interest_expressed_at ? l(pc.interest_expressed_at, format: :long) : "—"
        end
      end
    end

    if resource.interest_message.present?
      panel "Message client" do
        div class: "p-4 bg-gray-50 rounded" do
          simple_format(resource.interest_message)
        end
      end
    end

    if resource.summary.present?
      panel "Analyse" do
        div class: "space-y-4" do
          div do
            h4 "Résumé", class: "font-semibold mb-2"
            div class: "p-3 bg-gray-100 rounded" do
              simple_format(resource.summary)
            end
          end

          if resource.strengths.any?
            div do
              h4 "Points forts", class: "font-semibold mb-2 text-green-700"
              ul class: "list-disc ml-5" do
                resource.strengths.each do |s|
                  li s
                end
              end
            end
          end

          if resource.attention_points.any?
            div do
              h4 "Points d'attention", class: "font-semibold mb-2 text-orange-700"
              ul class: "list-disc ml-5" do
                resource.attention_points.each do |p|
                  li p
                end
              end
            end
          end
        end
      end
    end
  end

  controller do
    def scoped_collection
      end_of_association_chain.includes(
        :project,
        candidate: [:agent, { agent: :recruitment_office }]
      )
    end
  end
end
