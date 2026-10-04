module Candidate::ImportStateMachine
  extend ActiveSupport::Concern

  included do
    include AASM

    aasm :import_workflow, column: :import_status, enum: true do
      state :uploading, initial: true
      state :pending
      state :completed
      state :failed

      event :start_import_workflow do
        transitions from: [:pending, :uploading, :completed, :failed], to: :pending
        after do
          update_column(:publication_status, "draft")
          broadcast_publication_update
          Rails.logger.info "Candidate #{id}: Import started, publication_status set to draft"
        end
      end

      event :complete_import_workflow do
        transitions from: :pending, to: :completed
        after do
          broadcast_publication_update
          Rails.logger.info "Candidate #{id}: Import completed successfully"
        end
      end

      event :fail_import_workflow do
        transitions from: :pending, to: :failed
        after do
          broadcast_publication_update
          Rails.logger.info "Candidate #{id}: Import failed"
        end
      end
    end
  end

  private

  def broadcast_publication_update
    Turbo::StreamsChannel.broadcast_replace_to(
      "candidate_#{id}_updates",
      target: ActionView::RecordIdentifier.dom_id(self, :publication_block),
      partial: "agent/candidates/publication_block",
      locals: { candidate: self }
    )
  end
end
