require 'rails_helper'

RSpec.describe Candidate::ImportStateMachine, type: :model do
  let(:candidate) { create(:candidate) }

  describe 'states' do
    it 'has uploading as initial state' do
      expect(candidate.import_status).to eq('uploading')
    end

    it 'has all expected states' do
      expect(candidate.class.import_statuses.keys).to include('uploading', 'pending', 'completed', 'failed')
    end
  end

  describe 'transitions' do
    describe '#start_import_workflow' do
      before do
        allow(candidate).to receive(:broadcast_publication_update)
        allow(Rails.logger).to receive(:info)
      end

      context 'from uploading state' do
        before { candidate.update(import_status: :uploading) }

        it 'transitions to pending' do
          expect { candidate.start_import_workflow! }
            .to change { candidate.import_status }
            .from('uploading').to('pending')
        end

        it 'sets publication_status to draft' do
          candidate.update(publication_status: :published)
          expect { candidate.start_import_workflow! }
            .to change { candidate.reload.publication_status }
            .to('draft')
        end

        it 'broadcasts publication update' do
          expect(candidate).to receive(:broadcast_publication_update)
          candidate.start_import_workflow!
        end

        it 'logs the event' do
          expect(Rails.logger).to receive(:info).with("Candidate #{candidate.id}: Import started, publication_status set to draft")
          candidate.start_import_workflow!
        end
      end

      context 'from pending state' do
        before { candidate.update(import_status: :pending) }

        it 'can transition from pending to pending' do
          expect { candidate.start_import_workflow! }
            .not_to change { candidate.import_status }
        end
      end

      context 'from completed state' do
        before { candidate.update(import_status: :completed) }

        it 'can transition from completed to pending' do
          expect { candidate.start_import_workflow! }
            .to change { candidate.import_status }
            .from('completed').to('pending')
        end
      end

      context 'from failed state' do
        before { candidate.update(import_status: :failed) }

        it 'can transition from failed to pending' do
          expect { candidate.start_import_workflow! }
            .to change { candidate.import_status }
            .from('failed').to('pending')
        end
      end
    end

    describe '#complete_import_workflow' do
      context 'from pending state' do
        before do
          candidate.update(import_status: :pending)
          allow(candidate).to receive(:broadcast_publication_update)
          allow(Rails.logger).to receive(:info)
        end

        it 'transitions to completed' do
          expect { candidate.complete_import_workflow! }
            .to change { candidate.import_status }
            .from('pending').to('completed')
        end

        it 'broadcasts publication update' do
          expect(candidate).to receive(:broadcast_publication_update)
          candidate.complete_import_workflow!
        end

        it 'logs the event' do
          expect(Rails.logger).to receive(:info).with("Candidate #{candidate.id}: Import completed successfully")
          candidate.complete_import_workflow!
        end
      end

      context 'from uploading state' do
        before { candidate.update(import_status: :uploading) }

        it 'cannot transition from uploading' do
          expect { candidate.complete_import_workflow }.to raise_error(AASM::InvalidTransition)
        end
      end

      context 'from completed state' do
        before { candidate.update(import_status: :completed) }

        it 'cannot transition from completed' do
          expect { candidate.complete_import_workflow }.to raise_error(AASM::InvalidTransition)
        end
      end
    end

    describe '#fail_import_workflow' do
      context 'from pending state' do
        before do
          candidate.update(import_status: :pending)
          allow(candidate).to receive(:broadcast_publication_update)
          allow(Rails.logger).to receive(:info)
        end

        it 'transitions to failed' do
          expect { candidate.fail_import_workflow! }
            .to change { candidate.import_status }
            .from('pending').to('failed')
        end

        it 'broadcasts publication update' do
          expect(candidate).to receive(:broadcast_publication_update)
          candidate.fail_import_workflow!
        end

        it 'logs the event' do
          expect(Rails.logger).to receive(:info).with("Candidate #{candidate.id}: Import failed")
          candidate.fail_import_workflow!
        end
      end

      context 'from uploading state' do
        before { candidate.update(import_status: :uploading) }

        it 'cannot transition from uploading' do
          expect { candidate.fail_import_workflow }.to raise_error(AASM::InvalidTransition)
        end
      end

      context 'from completed state' do
        before { candidate.update(import_status: :completed) }

        it 'cannot transition from completed' do
          expect { candidate.fail_import_workflow }.to raise_error(AASM::InvalidTransition)
        end
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

  describe 'workflow states' do
    it 'can check if import is pending' do
      candidate.update(import_status: :pending)
      expect(candidate.import_pending?).to be_truthy
      expect(candidate.import_completed?).to be_falsey
    end

    it 'can check if import is completed' do
      candidate.update(import_status: :completed)
      expect(candidate.import_completed?).to be_truthy
      expect(candidate.import_pending?).to be_falsey
    end

    it 'can check if import failed' do
      candidate.update(import_status: :failed)
      expect(candidate.import_failed?).to be_truthy
      expect(candidate.import_completed?).to be_falsey
    end
  end

  describe 'AASM integration' do
    it 'uses the correct column' do
      expect(candidate.class.aasm(:import_workflow).attribute_name).to eq(:import_status)
    end

    it 'uses enum mapping' do
      # AASM enum is configured in the state machine definition
      expect(candidate.import_status).to be_a(String)
      expect(candidate.class.import_statuses).to be_a(Hash)
    end
  end

  describe 'transition combinations' do
    it 'can restart import multiple times' do
      candidate.update(import_status: :uploading)

      # Start import
      candidate.start_import_workflow!
      expect(candidate.import_status).to eq('pending')

      # Fail it
      candidate.fail_import_workflow!
      expect(candidate.import_status).to eq('failed')

      # Restart
      candidate.start_import_workflow!
      expect(candidate.import_status).to eq('pending')

      # Complete it
      candidate.complete_import_workflow!
      expect(candidate.import_status).to eq('completed')
    end
  end

  describe 'side effects' do
    it 'always sets publication_status to draft when starting import' do
      candidate.update(publication_status: :published)

      candidate.start_import_workflow!

      expect(candidate.reload.publication_status).to eq('draft')
    end

    it 'uses update_column for publication_status to avoid callbacks' do
      expect(candidate).to receive(:update_column).with(:publication_status, "draft")
      candidate.start_import_workflow!
    end
  end
end
