module Candidate::PublicationStateMachine
  extend ActiveSupport::Concern

  included do
    include AASM

    aasm :publication_workflow, column: :publication_status, enum: true do
      state :draft, initial: true
      state :pending
      state :published

      event :submit_for_review_workflow do
        transitions from: :draft, to: :pending, guard: :validation_errors_empty?
        after do
          save
          broadcast_publication_update
          # lancer l'analyse avant publication
          Rails.logger.info "Candidate #{id}: Submitted for review"
        end
      end

      event :publish_workflow do
        transitions from: [:draft, :pending], to: :published, guard: :publishable?
        after do
          update(published_at: DateTime.current, expires_at: 14.days.from_now)
          broadcast_publication_update
          Rails.logger.info "Candidate #{id}: Published successfully"
        end
      end

      event :unpublish_workflow do
        transitions from: :published, to: :draft
        after do
          clear_publication_data
          broadcast_publication_update
          Rails.logger.info "Candidate #{id}: Unpublished, back to draft"
        end
      end

      event :expire_workflow do
        transitions from: :published, to: :draft
        after do
          clear_publication_data
          broadcast_publication_update
          Rails.logger.info "Candidate #{id}: Expired automatically"
        end
      end

      event :reject_workflow do
        transitions from: :pending, to: :draft
        after do
          broadcast_publication_update
          Rails.logger.info "Candidate #{id}: Publication rejected, back to draft"
        end
      end
    end
  end

  private

  def validation_errors_empty?
    validation_errors.empty?
  end

  def clear_publication_data
    update_columns(
      published_at: nil,
      expires_at: nil,
      expiration_notified_at: nil
    )
  end

  def broadcast_publication_update
    Turbo::StreamsChannel.broadcast_replace_to(
      "candidate_#{id}_updates",
      target: ActionView::RecordIdentifier.dom_id(self, :publication_block),
      partial: "agent/candidates/publication_block",
      locals: { candidate: self }
    )
  end
end
