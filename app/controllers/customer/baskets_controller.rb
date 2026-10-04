class Customer::BasketsController < Customer::BaseController
  before_action :set_basket

  def show
    authorize @basket
    @status = params[:status] || "pending"

    case @status
    when "meeting_requested"
      @basket_items = @basket.basket_items.where(status: ["meeting_requested", "meeting_scheduled"]).includes(:agent, candidates: [:location])
    when "all"
      @basket_items = @basket.basket_items.includes(:agent, candidates: [:location])
    else # "pending"
      @basket_items = @basket.basket_items.where(status: "pending").includes(:agent, candidates: [:location])
    end
  end

  def add_candidate
    candidate = Candidate.find(params[:candidate_id])
    authorize candidate, :show?

    @basket_item = @basket.add_candidate(candidate)

    respond_to do |format|
      format.turbo_stream do
        streams = [
          turbo_stream.replace("basket-count", partial: "customer/baskets/count", locals: { count: @basket.pending_candidates_count }),
          turbo_stream.append("notifications", view_context.render(Notification::NoticeComponent.new(message: "Candidat ajouté à la shortlist")))
        ]

        # Si on est sur la page show du candidat, mettre à jour le bouton
        if request.referer&.include?("candidates/#{candidate.id}")
          streams << turbo_stream.replace("candidate-basket-button", partial: "customer/candidates/basket_button", locals: { candidate: candidate })
        # Si on est sur l'index, mettre à jour la card complète
        elsif request.referer&.include?("customer/candidates")
          @basket.reload
          streams << turbo_stream.replace("candidate-card-#{candidate.id}", partial: "customer/candidates/card", locals: { candidate: candidate })
        end

        render turbo_stream: streams
      end
      format.html do
        flash[:notice] = "Candidat ajouté à la shortlist"
        redirect_back(fallback_location: customer_candidates_path)
      end
    end
  end

  def remove_candidate
    authorize @basket, :remove_candidate?

    candidate = Candidate.find(params[:candidate_id])
    basket_item = @basket.basket_items.find(params[:basket_item_id])

    basket_item.remove_candidate(candidate)
    should_destroy = basket_item.candidates.empty?
    basket_item_id = basket_item.id
    basket_item.destroy if should_destroy

    respond_to do |format|
      format.turbo_stream do
        streams = []

        # Si on est sur la page show du candidat, mettre à jour le bouton
        if request.referer&.include?("candidates/#{candidate.id}") && !request.referer&.include?("customer/candidates?")
          streams << turbo_stream.replace("candidate-basket-button", partial: "customer/candidates/basket_button", locals: { candidate: candidate })
        # Si on est sur l'index, mettre à jour la card complète
        elsif request.referer&.include?("customer/candidates") && !request.referer&.include?("basket")
          streams << turbo_stream.replace("candidate-card-#{candidate.id}", partial: "customer/candidates/card", locals: { candidate: candidate })
        else
          # Sinon on est sur la page panier, on retire l'élément de la liste
          if should_destroy
            streams << turbo_stream.remove("basket_item_#{basket_item_id}")
          else
            streams << turbo_stream.remove("basket_candidate_#{candidate.id}")
          end
        end

        # Recalculer le count directement depuis la DB pour être sûr
        @basket.reload
        new_count = @basket.pending_candidates_count
        streams << turbo_stream.replace("basket-count", partial: "customer/baskets/count", locals: { count: new_count })
        streams << turbo_stream.append("notifications", view_context.render(Notification::NoticeComponent.new(message: "Candidat retiré")))

        render turbo_stream: streams
      end
      format.html do
        flash[:notice] = "Candidat retiré"
        redirect_to customer_basket_path
      end
    end
  end

  def request_meeting
    authorize @basket, :request_meeting?

    @basket_item = @basket.basket_items.find(params[:id])
    render layout: false
  end

  def send_meeting_request
    authorize @basket, :send_meeting_request?

    @basket_item = @basket.basket_items.find(params[:id])

    if @basket_item.request_meeting!(
      date: params[:meeting_date],
      message: params[:customer_message]
    )
      # Envoyer l'email à l'agent
      AgentMailer.meeting_request(basket_item: @basket_item).deliver_later
      # Envoyer l'email de confirmation au client
      CustomerMailer.meeting_request_confirmation(basket_item: @basket_item).deliver_later

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("modal", ""),
            turbo_stream.replace("basket_item_#{@basket_item.id}", partial: "customer/baskets/basket_item", locals: { basket_item: @basket_item }),
            turbo_stream.replace("basket-count", partial: "customer/baskets/count", locals: { count: @basket.pending_candidates_count }),
            turbo_stream.append("notifications", view_context.render(Notification::NoticeComponent.new(message: "Demande de RDV envoyée")))
          ]
        end
        format.html do
          flash[:notice] = "Demande de RDV envoyée"
          redirect_to customer_basket_path
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("modal", partial: "customer/baskets/meeting_form_errors", locals: { basket_item: @basket_item })
        end
        format.html do
          flash[:alert] = "Erreur lors de l'envoi de la demande"
          redirect_to customer_basket_path
        end
      end
    end
  end

  def calendar
    @basket_item = @basket.basket_items.find(params[:id])
    authorize @basket_item

    result = Calendar::GenerateInvite.call(basket_item: @basket_item)

    send_data result.ics_content,
              filename: "rdv-afternoon-#{@basket_item.id}.ics",
              type: 'text/calendar',
              disposition: 'attachment'
  end

  private

  def set_basket
    @basket = current_basket
  end
end
