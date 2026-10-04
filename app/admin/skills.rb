ActiveAdmin.register Skill do
  menu priority: 10, label: "Skills"

  actions :index, :edit, :update

  config.clear_action_items!

  scope :all, default: true
  scope("Sans semantic") { |scope| scope.where("semantic = '[]'::jsonb") }
  scope("Sans embedding") { |scope| scope.where(embedding: nil) }
  scope("Complets") { |scope| scope.where("semantic != '[]'::jsonb").where.not(embedding: nil) }

  filter :name

  permit_params :name, semantic: []

  form do |f|
    f.inputs do
      f.input :name
      f.input :semantic,
              as: :text,
              input_html: { value: f.object.semantic&.join(", "), rows: 3 },
              hint: "Termes séparés par des virgules. Ex: management, encadrement, supervision d'équipe"
    end
    f.actions
  end

  controller do
    def update
      # Transformer la string CSV en array avant save
      if params[:skill][:semantic].is_a?(String)
        params[:skill][:semantic] = params[:skill][:semantic]
          .split(",")
          .map(&:strip)
          .reject(&:blank?)
      end

      update! do |success, failure|
        success.html do
          Skill::EmbedJob.perform_async(resource.id)
          redirect_to admin_skills_path, notice: "« #{resource.name} » mis à jour — embedding en cours de régénération"
        end
        failure.html { render :edit }
      end
    end
  end

  index download_links: false do
    selectable_column
    id_column
    column :name
    column :slug
    column "Semantic" do |skill|
      if skill.semantic.present? && skill.semantic.any?
        span title: skill.semantic.join(", ") do
          status_tag "#{skill.semantic.size} termes", class: "bg-green-100 text-green-800"
        end
      else
        status_tag "vide", class: "bg-red-100 text-red-800"
      end
    end
    column "Embedding" do |skill|
      if skill.embedding.present?
        status_tag "ok", class: "bg-green-100 text-green-800"
      else
        status_tag "manquant", class: "bg-red-100 text-red-800"
      end
    end
    column "Candidats" do |skill|
      skill.candidates.count
    end
    actions defaults: false do |skill|
      item "Edit", edit_admin_skill_path(skill), class: "action-item-button"
      item "Semantic", generate_semantic_admin_skill_path(skill), method: :put, class: "action-item-button"
      item "Embedding", generate_embedding_admin_skill_path(skill), method: :put, class: "action-item-button"
    end
  end

  # --- Actions unitaires ---

  member_action :generate_semantic, method: :put do
    Skill::GenerateSemanticJob.perform_async(resource.id)
    redirect_to admin_skills_path, notice: "Génération semantic lancée pour « #{resource.name} »"
  end

  member_action :generate_embedding, method: :put do
    Skill::EmbedJob.perform_async(resource.id)
    redirect_to admin_skills_path, notice: "Génération embedding lancée pour « #{resource.name} »"
  end

  # --- Actions en lot ---

  batch_action "Générer semantic", confirm: "Lancer la génération semantic pour les skills sélectionnées ?" do |ids|
    batch_action_collection.find(ids).each do |skill|
      Skill::GenerateSemanticJob.perform_async(skill.id)
    end
    redirect_to admin_skills_path, notice: "Génération semantic lancée pour #{ids.size} skills"
  end

  batch_action "Générer embedding", confirm: "Lancer la génération embedding pour les skills sélectionnées ?" do |ids|
    batch_action_collection.find(ids).each do |skill|
      Skill::EmbedJob.perform_async(skill.id)
    end
    redirect_to admin_skills_path, notice: "Génération embedding lancée pour #{ids.size} skills"
  end

  # Raccourci : backfill tout ce qui manque
  action_item :backfill_semantic, only: :index do
    missing = Skill.where("semantic = '[]'::jsonb").count
    if missing > 0
      link_to "Backfill semantic (#{missing})",
              backfill_semantic_admin_skills_path,
              method: :post,
              data: { confirm: "Lancer le semantic sur #{missing} skills ?" }
    end
  end

  action_item :backfill_embedding, only: :index do
    missing = Skill.where(embedding: nil).count
    if missing > 0
      link_to "Backfill embedding (#{missing})",
              backfill_embedding_admin_skills_path,
              method: :post,
              data: { confirm: "Lancer l'embedding sur #{missing} skills ?" }
    end
  end

  collection_action :backfill_semantic, method: :post do
    skills = Skill.where("semantic = '[]'::jsonb")
    skills.find_each { |s| Skill::GenerateSemanticJob.perform_async(s.id) }
    redirect_to admin_skills_path, notice: "Semantic lancé pour #{skills.count} skills"
  end

  collection_action :backfill_embedding, method: :post do
    skills = Skill.where(embedding: nil)
    skills.find_each { |s| Skill::EmbedJob.perform_async(s.id) }
    redirect_to admin_skills_path, notice: "Embedding lancé pour #{skills.count} skills"
  end
end
