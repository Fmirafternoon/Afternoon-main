class Customer::SavedSearchesController < Customer::BaseController
  before_action :set_saved_search, only: [:destroy, :load, :toggle_alerts]

  def new
    @saved_search = current_user.saved_searches.build
    authorize @saved_search
    @search_form = Customer::SearchForm.new(search_params)
    render layout: false
  end

  def create
    @saved_search = current_user.saved_searches.build(saved_search_params)
    authorize @saved_search

    if @saved_search.save
      respond_to do |format|
        format.turbo_stream do
          # Fermer la modal
          turbo_stream_response = turbo_stream.update("modal", "")

          # Rafraîchir la section des recherches sauvegardées
          turbo_stream_response += turbo_stream.replace(
            "saved-searches-section",
            partial: "customer/candidates/saved_searches_section",
            locals: {
              saved_searches: current_user.saved_searches.ordered,
              active_saved_search_id: @saved_search.id
            }
          )

          # Si c'est la première recherche, on doit créer la section
          if current_user.saved_searches.count == 1
            turbo_stream_response = turbo_stream.update("modal", "")
            turbo_stream_response += turbo_stream.replace(
              "saved-searches-container",
              partial: "customer/candidates/saved_searches_section",
              locals: {
                saved_searches: current_user.saved_searches.ordered,
                active_saved_search_id: @saved_search.id
              }
            )
          end

          # Ajouter la notification
          turbo_stream_response += turbo_stream.append(
            "notifications",
            view_context.render(Notification::NoticeComponent.new(message: 'Recherche sauvegardée avec succès'))
          )
          
          render turbo_stream: turbo_stream_response
        end

        format.html do
          flash[:notice] = "Recherche sauvegardée avec succès"
          redirect_to customer_candidates_path(@saved_search.criteria.merge(saved_search_id: @saved_search.id))
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "modal",
            partial: "customer/saved_searches/form_errors",
            locals: { saved_search: @saved_search, search_form: Customer::SearchForm.new }
          )
        end
      end
    end
  end

  def destroy
    authorize @saved_search
    @saved_search.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("saved_search_#{@saved_search.id}"),
          turbo_stream.append(
            "notifications",
            view_context.render(Notification::NoticeComponent.new(message: 'Recherche supprimée'))
          )
        ]
      end

      format.html do
        flash[:notice] = "Recherche supprimée"
        redirect_to customer_candidates_path
      end
    end
  end

  def load
    authorize @saved_search
    @saved_search.touch_last_used_at!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "search-form",
          partial: "customer/candidates/search_form",
          locals: {
            search_form: Customer::SearchForm.new(@saved_search.criteria),
            saved_search_id: @saved_search.id
          }
        )
      end
      format.html do
        redirect_to customer_candidates_path(@saved_search.criteria.merge(saved_search_id: @saved_search.id))
      end
    end
  end

  def toggle_alerts
    authorize @saved_search
    @saved_search.toggle_email_alerts!
    
    message = @saved_search.email_alerts_enabled? ? 'Alertes activées' : 'Alertes désactivées'
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "saved_search_#{@saved_search.id}",
            partial: "customer/candidates/saved_search_item",
            locals: { saved_search: @saved_search }
          ),
          turbo_stream.append(
            "notifications",
            view_context.render(Notification::NoticeComponent.new(message: message))
          )
        ]
      end
      format.html do
        flash[:notice] = message
        redirect_to customer_candidates_path
      end
    end
  end


  private

  def set_saved_search
    @saved_search = current_user.saved_searches.find(params[:id])
  end

  def saved_search_params
    # Parse JSON string to hash if needed
    if params[:saved_search][:criteria].is_a?(String)
      parsed_criteria = JSON.parse(params[:saved_search][:criteria]) rescue {}
      params[:saved_search][:criteria] = parsed_criteria
    end

    params.require(:saved_search).permit(:name, :email_alerts_enabled, criteria: {})
  end

  def search_params
    params.permit(:query, :lat, :lng, :autocomplete_address, :zip_code, :city, sector_ids: [], skills: [])
  end
end
