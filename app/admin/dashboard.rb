# frozen_string_literal: true
ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    # Calcul des KPIs
    total_candidates = Candidate.kept.count
    published_candidates = Candidate.kept.published.count
    total_offices = RecruitmentOffice.count
    total_agents = User.kept.where(role: [:agent_user, :agent_manager]).count

    # Calcul des évolutions (par rapport au mois dernier)
    last_month_start = 1.month.ago.beginning_of_month
    last_month_end = 1.month.ago.end_of_month

    candidates_last_month = Candidate.kept.where("created_at >= ?", last_month_start).count
    candidates_previous_month = Candidate.kept.where("created_at >= ? AND created_at <= ?",
                                                      2.months.ago.beginning_of_month,
                                                      2.months.ago.end_of_month).count

    offices_last_month = RecruitmentOffice.where("created_at >= ?", last_month_start).count
    agents_last_month = User.kept.where(role: [:agent_user, :agent_manager])
                            .where("created_at >= ?", last_month_start).count

    # Calcul du pourcentage d'évolution pour les candidats
    candidates_percentage = if candidates_previous_month > 0
                             (((candidates_last_month.to_f - candidates_previous_month) / candidates_previous_month) * 100).round
                           elsif candidates_last_month > 0
                             100
                           else
                             0
                           end

    # Grid de 4 cartes sur la même ligne
    div class: "grid grid-cols-4 gap-6 mb-8" do
      # Carte 1: Candidats
      div class: "bg-white dark:bg-gray-800 rounded-lg shadow p-6" do
        div class: "flex gap-4 items-end" do
          # Colonne gauche: Icône + Titre et Chiffre
          div class: "flex-1" do
            div class: "flex items-center gap-2 mb-2" do
              span "👥", class: "text-2xl"
              div class: "text-sm font-semibold text-gray-600 dark:text-gray-400" do
                text_node "Candidats"
              end
            end
            div class: "text-[32px] font-bold text-gray-900 dark:text-white leading-none" do
              text_node total_candidates.to_s
            end
          end

          # Colonne droite: Stat
          div class: "text-right" do
            color_class = candidates_percentage >= 0 ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"
            sign = candidates_percentage >= 0 ? "+" : ""
            div class: "text-sm font-semibold #{color_class}" do
              text_node "#{sign}#{candidates_percentage}%"
            end
            div class: "text-xs text-gray-500 dark:text-gray-400" do
              text_node "#{sign}#{candidates_last_month} ce mois"
            end
          end
        end
      end

      # Carte 2: Candidats publiés
      div class: "bg-white dark:bg-gray-800 rounded-lg shadow p-6" do
        div class: "flex gap-4 items-end" do
          # Colonne gauche: Icône + Titre et Chiffre
          div class: "flex-1" do
            div class: "flex items-center gap-2 mb-2" do
              span "📝", class: "text-2xl"
              div class: "text-sm font-semibold text-gray-600 dark:text-gray-400" do
                text_node "Publiés"
              end
            end
            div class: "text-[32px] font-bold text-gray-900 dark:text-white leading-none" do
              text_node published_candidates.to_s
            end
          end

          # Colonne droite: Stat
          div class: "text-right" do
            if total_candidates > 0
              percentage = ((published_candidates.to_f / total_candidates) * 100).round
              div class: "text-sm font-semibold text-blue-600 dark:text-blue-400" do
                text_node "#{percentage}%"
              end
              div class: "text-xs text-gray-500 dark:text-gray-400" do
                text_node "du total"
              end
            end
          end
        end
      end

      # Carte 3: Cabinets
      div class: "bg-white dark:bg-gray-800 rounded-lg shadow p-6" do
        div class: "flex gap-4 items-end" do
          # Colonne gauche: Icône + Titre et Chiffre
          div class: "flex-1" do
            div class: "flex items-center gap-2 mb-2" do
              span "🏢", class: "text-2xl"
              div class: "text-sm font-semibold text-gray-600 dark:text-gray-400" do
                text_node "Cabinets"
              end
            end
            div class: "text-[32px] font-bold text-gray-900 dark:text-white leading-none" do
              text_node total_offices.to_s
            end
          end

          # Colonne droite: Stat
          div class: "text-right" do
            if offices_last_month > 0
              div class: "text-sm font-semibold text-green-600 dark:text-green-400" do
                text_node "+#{offices_last_month}"
              end
              div class: "text-xs text-gray-500 dark:text-gray-400" do
                text_node "ce mois"
              end
            end
          end
        end
      end

      # Carte 4: Agents
      div class: "bg-white dark:bg-gray-800 rounded-lg shadow p-6" do
        div class: "flex gap-4 items-end" do
          # Colonne gauche: Icône + Titre et Chiffre
          div class: "flex-1" do
            div class: "flex items-center gap-2 mb-2" do
              span "👔", class: "text-2xl"
              div class: "text-sm font-semibold text-gray-600 dark:text-gray-400" do
                text_node "Agents"
              end
            end
            div class: "text-[32px] font-bold text-gray-900 dark:text-white leading-none" do
              text_node total_agents.to_s
            end
          end

          # Colonne droite: Stat
          div class: "text-right" do
            if agents_last_month > 0
              div class: "text-sm font-semibold text-green-600 dark:text-green-400" do
                text_node "+#{agents_last_month}"
              end
              div class: "text-xs text-gray-500 dark:text-gray-400" do
                text_node "ce mois"
              end
            end
          end
        end
      end
    end

    # Section Projets
    div class: "mt-8" do
      h3 "Activité Projets", class: "text-lg font-semibold text-gray-900 dark:text-white mb-4"
    end

    # KPIs Projets
    active_projects = Project.active.count
    total_projects = Project.count
    this_month_start = Time.current.beginning_of_month

    pushed_this_month = ProjectCandidate.where(status: :pushed)
                                        .where("pushed_at >= ?", this_month_start).count
    pushed_last_month = ProjectCandidate.where(status: :pushed)
                                        .where("pushed_at >= ? AND pushed_at < ?",
                                               1.month.ago.beginning_of_month,
                                               this_month_start).count

    interested_this_month = ProjectCandidate.interested
                                            .where("interest_expressed_at >= ?", this_month_start).count
    interested_total = ProjectCandidate.interested.count

    rejected_this_month = ProjectCandidate.rejected
                                          .where("updated_at >= ?", this_month_start).count

    # Taux de conversion: intéressés / présentés (tous temps)
    total_pushed = ProjectCandidate.where(status: [:pushed, :interested, :rejected, :hired]).count
    conversion_rate = total_pushed > 0 ? ((interested_total.to_f / total_pushed) * 100).round : 0

    div class: "grid grid-cols-4 gap-6 mb-8" do
      # Carte 1: Projets actifs
      div class: "bg-white dark:bg-gray-800 rounded-lg shadow p-6" do
        div class: "flex gap-4 items-end" do
          div class: "flex-1" do
            div class: "flex items-center gap-2 mb-2" do
              span "📋", class: "text-2xl"
              div class: "text-sm font-semibold text-gray-600 dark:text-gray-400" do
                text_node "Projets actifs"
              end
            end
            div class: "text-[32px] font-bold text-gray-900 dark:text-white leading-none" do
              text_node active_projects.to_s
            end
          end
          div class: "text-right" do
            div class: "text-sm font-semibold text-gray-500" do
              text_node "/ #{total_projects}"
            end
            div class: "text-xs text-gray-500 dark:text-gray-400" do
              text_node "total"
            end
          end
        end
      end

      # Carte 2: Candidats présentés
      div class: "bg-white dark:bg-gray-800 rounded-lg shadow p-6" do
        div class: "flex gap-4 items-end" do
          div class: "flex-1" do
            div class: "flex items-center gap-2 mb-2" do
              span "📤", class: "text-2xl"
              div class: "text-sm font-semibold text-gray-600 dark:text-gray-400" do
                text_node "Présentés"
              end
            end
            div class: "text-[32px] font-bold text-blue-600 dark:text-blue-400 leading-none" do
              text_node pushed_this_month.to_s
            end
          end
          div class: "text-right" do
            diff = pushed_this_month - pushed_last_month
            color = diff >= 0 ? "text-green-600" : "text-red-600"
            sign = diff >= 0 ? "+" : ""
            div class: "text-sm font-semibold #{color}" do
              text_node "#{sign}#{diff}"
            end
            div class: "text-xs text-gray-500 dark:text-gray-400" do
              text_node "vs mois préc."
            end
          end
        end
      end

      # Carte 3: Intérêts clients
      div class: "bg-white dark:bg-gray-800 rounded-lg shadow p-6" do
        div class: "flex gap-4 items-end" do
          div class: "flex-1" do
            div class: "flex items-center gap-2 mb-2" do
              span "💚", class: "text-2xl"
              div class: "text-sm font-semibold text-gray-600 dark:text-gray-400" do
                text_node "Intérêts"
              end
            end
            div class: "text-[32px] font-bold text-green-600 dark:text-green-400 leading-none" do
              text_node interested_this_month.to_s
            end
          end
          div class: "text-right" do
            div class: "text-sm font-semibold text-red-600" do
              text_node rejected_this_month.to_s
            end
            div class: "text-xs text-gray-500 dark:text-gray-400" do
              text_node "rejetés"
            end
          end
        end
      end

      # Carte 4: Taux de conversion
      div class: "bg-white dark:bg-gray-800 rounded-lg shadow p-6" do
        div class: "flex gap-4 items-end" do
          div class: "flex-1" do
            div class: "flex items-center gap-2 mb-2" do
              span "📊", class: "text-2xl"
              div class: "text-sm font-semibold text-gray-600 dark:text-gray-400" do
                text_node "Conversion"
              end
            end
            div class: "text-[32px] font-bold text-gray-900 dark:text-white leading-none" do
              text_node "#{conversion_rate}%"
            end
          end
          div class: "text-right" do
            div class: "text-sm font-semibold text-gray-500" do
              text_node "#{interested_total}/#{total_pushed}"
            end
            div class: "text-xs text-gray-500 dark:text-gray-400" do
              text_node "intérêts/présentés"
            end
          end
        end
      end
    end
  end
end
