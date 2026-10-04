ActiveAdmin.register RecruitmentOffice do
  menu priority: 2

  permit_params :name, :address, :zip_code, :city, :url, :vat_number, :siret_number

  config.clear_action_items!

  action_item :new, only: :index do
    link_to "Nouveau cabinet", "/admin/recruitment_offices/new", class: "action-item-button"
  end

  action_item :edit, only: :show do
    link_to "Modifier", edit_admin_recruitment_office_path(resource), class: "action-item-button"
  end

  action_item :delete, only: :show do
    link_to "Supprimer", admin_recruitment_office_path(resource), method: :delete, data: { confirm: "Êtes-vous sûr ? Tous les agents associés seront également supprimés." }, class: "action-item-button"
  end

  # Index avec colonnes personnalisées
  index download_links: false do
    selectable_column
    column "Nom" do |office|
      link_to office.name, "/admin/recruitment_offices/#{office.id}"
    end
    column :address, sortable: false
    column :city, sortable: false
    column :siret_number, sortable: false
    column "Agents" do |office|
      office.agents.count
    end
    actions defaults: false do |office|
      item "Voir", "/admin/recruitment_offices/#{office.id}", class: "member_link"
      item "Modifier", "/admin/recruitment_offices/#{office.id}/edit", class: "member_link"
      item "Supprimer", "/admin/recruitment_offices/#{office.id}", method: :delete, data: { confirm: "Êtes-vous sûr ? Tous les agents associés seront également supprimés." }, class: "member_link"
    end
  end

  config.filters = false

  # Formulaire
  form do |f|
    f.inputs "Informations du cabinet" do
      f.input :name
      f.input :address
      f.input :zip_code
      f.input :city
      f.input :url
      f.input :vat_number
      f.input :siret_number
    end
    f.actions
  end

  # Page de détails
  show do
    attributes_table do
      row :id
      row :name
      row :address
      row :zip_code
      row :city
      row :url do |office|
        link_to office.url, office.url, target: "_blank" if office.url.present?
      end
      row :vat_number
      row :siret_number
      row "Nombre d'agents" do |office|
        office.agents.count
      end
      row :created_at
      row :updated_at
    end

    panel "Agents" do
      table_for recruitment_office.agents do
        column "Nom" do |agent|
          link_to agent.full_name, "/admin/users/#{agent.id}"
        end
        column :email
        column :role do |agent|
          status_tag agent.role
        end
      end
    end
  end

  controller do
    def destroy
      @recruitment_office = RecruitmentOffice.find(params[:id])

      if @recruitment_office.agents.any?
        redirect_to admin_recruitment_offices_path,
                    alert: "Impossible de supprimer ce cabinet car il a #{@recruitment_office.agents.count} agent(s) associé(s). Veuillez d'abord supprimer ou réassigner les agents."
      else
        @recruitment_office.destroy
        redirect_to admin_recruitment_offices_path, notice: "Cabinet supprimé avec succès"
      end
    end

    def scoped_collection
      end_of_association_chain
    end
  end
end
