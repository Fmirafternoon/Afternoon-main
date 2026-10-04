ActiveAdmin.register User do
  menu priority: 1

  permit_params :email, :first_name, :last_name, :role, :recruitment_office_id

  config.clear_action_items!

  action_item :new, only: :index do
    link_to "Nouvel utilisateur", "/admin/users/new", class: "action-item-button"
  end

  action_item :impersonate, only: :show, if: -> { policy(resource).impersonate? } do
    link_to impersonate_admin_user_path(resource), method: :post, class: "action-item-button" do
      raw('<span style="margin-right: 0.5rem;">👻</span> Impersonate')
    end
  end

  action_item :edit, only: :show do
    link_to "Modifier", edit_admin_user_path(resource), class: "action-item-button"
  end

  action_item :delete, only: :show, if: -> { policy(resource).destroy? } do
    link_to "Supprimer", admin_user_path(resource), method: :delete, data: { confirm: "Êtes-vous sûr ?" }, class: "action-item-button"
  end

  # Index avec colonnes personnalisées
  index download_links: false do
    selectable_column
    column "Nom" do |user|
      text_node link_to(user.full_name, "/admin/users/#{user.id}")
      text_node " 🔴" if user.low_completion_alert?
    end
    column "Rôle" do |user|
      status_tag user.role, class: "user-role-#{user.role}"
    end
    column "Complétion moyenne" do |user|
      if user.average_completion_percentage.present?
        style = user.low_completion_alert? ? "color: #D32F2F; font-weight: bold;" : nil
        span "#{user.average_completion_percentage} %", style: style
      end
    end
    column "Cabinet" do |user|
      if user.agent? && user.recruitment_office
        link_to user.recruitment_office.name, "/admin/recruitment_offices/#{user.recruitment_office.id}"
      end
    end
    column :email, sortable: false
    column "Invité le", :invitation_sent_at, sortable: false
    actions defaults: false do |user|
      item "Voir", "/admin/users/#{user.id}", class: "member_link"
      item "Modifier", "/admin/users/#{user.id}/edit", class: "member_link"
      item "Inviter", "/admin/users/#{user.id}/invite", method: :post, class: "member_link" if policy(user).invite?
      item "Supprimer", "/admin/users/#{user.id}", method: :delete, data: { confirm: "Êtes-vous sûr ?" }, class: "member_link" if policy(user).destroy?
    end
  end

  # Filtres (désactivés temporairement à cause de problèmes de routes)
  # filter :email
  # filter :first_name
  # filter :last_name
  # filter :role, as: :select, collection: User.roles.keys
  # filter :recruitment_office
  # filter :created_at

  config.filters = false

  # Formulaire
  form do |f|
    f.inputs "Informations de l'utilisateur" do
      f.input :email
      f.input :first_name
      f.input :last_name
      f.input :role, as: :select, collection: User.roles.keys, include_blank: false
      f.input :recruitment_office, collection: RecruitmentOffice.all,
              include_blank: "Aucun (pour non-agent)",
              input_html: { disabled: f.object.role.present? && !f.object.agent? }
    end
    f.actions
  end

  # Page de détails
  show do
    attributes_table do
      row :id
      row "Nom complet" do |user|
        user.full_name
      end
      row :email
      row "Rôle" do |user|
        status_tag user.role
      end
      row "Cabinet" do |user|
        if user.agent? && user.recruitment_office
          link_to user.recruitment_office.name, "/admin/recruitment_offices/#{user.recruitment_office.id}"
        else
          "N/A"
        end
      end
      row "Invitation envoyée le" do |user|
        user.invitation_sent_at ? l(user.invitation_sent_at) : "Pas encore envoyée"
      end
      row "Mot de passe créé le" do |user|
        user.password_set_at ? l(user.password_set_at) : "Pas encore créé"
      end
      row :created_at
      row :updated_at
    end

    panel "Actions" do
      div class: "button-group" do
        link_to "Inviter", "/admin/users/#{user.id}/invite", method: :post, class: "button"
      end
    end
  end

  # Actions personnalisées
  member_action :invite, method: :post do
    user = User.find(params[:id])
    authorize user, :invite?

    UserMailer.password_creation(user).deliver_later
    user.update(invitation_sent_at: Time.current)

    redirect_to "/admin/users/#{user.id}", notice: "Invitation envoyée à #{user.email}"
  end

  member_action :impersonate, method: :post do
    user = User.find(params[:id])
    authorize user, :impersonate?

    # Stocker l'URL de retour pour le bouton Stop
    session[:impersonation_return_to] = request.referer || admin_users_path

    impersonate_user(user)
    redirect_to root_path, notice: "Vous consultez l'application en tant que #{user.full_name}"
  end

  # Controller personnalisé pour la création
  controller do
    def create
      @user = User.new(permitted_params[:user])
      @user.password = Devise.friendly_token.first(16)

      if @user.save
        UserMailer.password_creation(@user).deliver_later
        @user.update(invitation_sent_at: Time.current)
        redirect_to "/admin/users/#{@user.id}", notice: "Utilisateur créé et invitation envoyée"
      else
        render :new
      end
    end

    def destroy
      @user = User.find(params[:id])
      @user.discard
      redirect_to admin_users_path, notice: "Utilisateur supprimé (soft delete)"
    end

    def scoped_collection
      end_of_association_chain.kept
    end
  end
end
