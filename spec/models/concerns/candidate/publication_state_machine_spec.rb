require 'rails_helper'

RSpec.describe Candidate::PublicationStateMachine, type: :model do
  let(:candidate) { create(:candidate) }

  describe 'states' do
    it 'has draft as initial state' do
      expect(candidate.publication_status).to eq('draft')
    end

    it 'has all expected states' do
      expect(candidate.class.publication_statuses.keys).to include('draft', 'pending', 'published')
    end
  end

  describe 'transitions' do
    describe '#submit_for_review_workflow' do
      context 'from draft state' do
        before { candidate.update(publication_status: :draft) }

        context 'when validation errors are empty' do
          before do
            allow(candidate).to receive(:validation_errors_empty?).and_return(true)
            allow(candidate).to receive(:broadcast_publication_update)
          end

          it 'transitions to pending' do
            expect { candidate.submit_for_review_workflow! }
              .to change { candidate.publication_status }
              .from('draft').to('pending')
          end

          it 'saves the candidate' do
            expect(candidate).to receive(:save)
            candidate.submit_for_review_workflow!
          end

          it 'broadcasts publication update' do
            expect(candidate).to receive(:broadcast_publication_update)
            candidate.submit_for_review_workflow!
          end
        end

        context 'when validation errors are present' do
          before do
            allow(candidate).to receive(:validation_errors_empty?).and_return(false)
          end

          it 'raises an error' do
            expect { candidate.submit_for_review_workflow }.to raise_error(AASM::InvalidTransition)
          end
        end
      end

      context 'from published state' do
        before { candidate.update(publication_status: :published) }

        it 'cannot transition from published' do
          expect { candidate.submit_for_review_workflow }.to raise_error(AASM::InvalidTransition)
        end
      end
    end

    describe '#publish_workflow' do
      context 'when publishable' do
        before do
          allow(candidate).to receive(:publishable?).and_return(true)
          allow(candidate).to receive(:broadcast_publication_update)
        end

        context 'from draft state' do
          before { candidate.update(publication_status: :draft) }

          it 'transitions to published' do
            expect { candidate.publish_workflow! }
              .to change { candidate.publication_status }
              .from('draft').to('published')
          end

          it 'sets published_at timestamp' do
            freeze_time do
              expect { candidate.publish_workflow! }
                .to change { candidate.published_at }
                .from(nil).to(DateTime.current)
            end
          end
        end

        context 'from pending state' do
          before { candidate.update(publication_status: :pending) }

          it 'transitions to published' do
            expect { candidate.publish_workflow! }
              .to change { candidate.publication_status }
              .from('pending').to('published')
          end
        end
      end

      context 'when not publishable' do
        before do
          allow(candidate).to receive(:publishable?).and_return(false)
        end

        it 'raises an error' do
          expect { candidate.publish_workflow }.to raise_error(AASM::InvalidTransition)
        end
      end
    end

    describe '#unpublish_workflow' do
      context 'from published state' do
        before do
          candidate.update(publication_status: :published, published_at: 1.hour.ago)
          allow(candidate).to receive(:broadcast_publication_update)
        end

        it 'transitions to draft' do
          expect { candidate.unpublish_workflow! }
            .to change { candidate.publication_status }
            .from('published').to('draft')
        end

        it 'clears published_at timestamp' do
          expect { candidate.unpublish_workflow! }
            .to change { candidate.reload.published_at }
            .to(nil)
        end

        it 'broadcasts publication update' do
          expect(candidate).to receive(:broadcast_publication_update)
          candidate.unpublish_workflow!
        end
      end

      context 'from draft state' do
        before { candidate.update(publication_status: :draft) }

        it 'cannot transition from draft' do
          expect { candidate.unpublish_workflow }.to raise_error(AASM::InvalidTransition)
        end
      end
    end

    describe '#reject_workflow' do
      context 'from pending state' do
        before do
          candidate.update(publication_status: :pending)
          allow(candidate).to receive(:broadcast_publication_update)
        end

        it 'transitions to draft' do
          expect { candidate.reject_workflow! }
            .to change { candidate.publication_status }
            .from('pending').to('draft')
        end

        it 'broadcasts publication update' do
          expect(candidate).to receive(:broadcast_publication_update)
          candidate.reject_workflow!
        end
      end

      context 'from published state' do
        before { candidate.update(publication_status: :published) }

        it 'cannot transition from published' do
          expect { candidate.reject_workflow }.to raise_error(AASM::InvalidTransition)
        end
      end
    end
  end

  describe 'guards' do
    describe '#validation_errors_empty?' do
      it 'returns true when validation_errors is empty' do
        allow(candidate).to receive(:validation_errors).and_return({})
        expect(candidate.send(:validation_errors_empty?)).to be_truthy
      end

      it 'returns false when validation_errors has content' do
        allow(candidate).to receive(:validation_errors).and_return({ step: ['error'] })
        expect(candidate.send(:validation_errors_empty?)).to be_falsey
      end
    end
  end

  describe '#broadcast_publication_update' do
    it 'broadcasts to the correct stream' do
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
        "candidate_#{candidate.id}_updates",
        hash_including(
          target: anything,
          partial: "agent/candidates/publication_block",
          locals: { candidate: candidate }
        )
      )

      candidate.send(:broadcast_publication_update)
    end
  end

  describe 'logging' do
    before do
      allow(candidate).to receive(:broadcast_publication_update)
      allow(Rails.logger).to receive(:info)
    end

    it 'logs submit_for_review_workflow event' do
      allow(candidate).to receive(:validation_errors_empty?).and_return(true)

      expect(Rails.logger).to receive(:info).with("Candidate #{candidate.id}: Submitted for review")
      candidate.submit_for_review_workflow!
    end

    it 'logs publish_workflow event' do
      allow(candidate).to receive(:publishable?).and_return(true)

      expect(Rails.logger).to receive(:info).with("Candidate #{candidate.id}: Published successfully")
      candidate.publish_workflow!
    end

    it 'logs unpublish_workflow event' do
      candidate.update(publication_status: :published)

      expect(Rails.logger).to receive(:info).with("Candidate #{candidate.id}: Unpublished, back to draft")
      candidate.unpublish_workflow!
    end

    it 'logs reject_workflow event' do
      candidate.update(publication_status: :pending)

      expect(Rails.logger).to receive(:info).with("Candidate #{candidate.id}: Publication rejected, back to draft")
      candidate.reject_workflow!
    end
  end

  describe 'AASM integration' do
    it 'uses the correct column' do
      expect(candidate.class.aasm(:publication_workflow).attribute_name).to eq(:publication_status)
    end

    it 'uses enum mapping' do
      # AASM enum is configured in the state machine definition
      expect(candidate.publication_status).to be_a(String)
      expect(candidate.class.publication_statuses).to be_a(Hash)
    end
  end
end
