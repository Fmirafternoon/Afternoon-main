class Customer::CandidatesController < Customer::BaseController
  def index
    scope = policy_scope(Candidate)

    # Handle skills normalization (add new + remove duplicates)
    current_skills = params.dig(:customer_search_form, :skills) || []
    new_skill = params.dig(:customer_search_form, :new_skill)&.strip

    normalized_skills = current_skills.dup
    normalized_skills << new_skill if new_skill.present? && !normalized_skills.include?(new_skill)
    normalized_skills.uniq!

    # Handle sector_ids normalization (remove duplicates)
    current_sector_ids = params.dig(:customer_search_form, :sector_ids) || []
    normalized_sector_ids = current_sector_ids.map(&:to_s).uniq

    # Redirect if skills or sectors changed
    if normalized_skills != current_skills || normalized_sector_ids != current_sector_ids.map(&:to_s)
      redirect_params = search_params.merge(
        "skills" => normalized_skills,
        "sector_ids" => normalized_sector_ids
      )
      redirect_to customer_candidates_path(customer_search_form: redirect_params) and return
    end

    @search_form = Customer::SearchForm.new(search_params)
    session[:search_form] = @search_form.attributes

    @candidates = Candidate::Search.call(
      scope: scope,
      form: @search_form
    ).candidates.published.kept

    # Load saved searches for current customer
    @saved_searches = current_user.saved_searches.ordered if current_user.customer?
    @active_saved_search_id = params[:saved_search_id]
  end

  def show
    @candidate = Candidate.find(params[:id])
    authorize @candidate
  end

  private

  def search_params
    # Si les paramètres viennent d'une recherche sauvegardée, ils sont directement dans params
    if params[:customer_search_form].blank? && params[:saved_search_id].present?
      permitted_params = params.permit(
        :query,
        :lat,
        :lng,
        :autocomplete_address,
        :zip_code,
        :city,
        sector_ids: [],
        skills: []
      )
      # Enlever saved_search_id des paramètres de recherche
      permitted_params.except(:saved_search_id)
    elsif params[:customer_search_form].present?
      params.require(:customer_search_form).permit(
        :query,
        :lat,
        :lng,
        :autocomplete_address,
        :zip_code,
        :city,
        sector_ids: [],
        skills: []
      )
    else
      {}
    end
  end
end
