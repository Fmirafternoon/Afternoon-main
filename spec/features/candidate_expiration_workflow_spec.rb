require 'rails_helper'

RSpec.describe 'Candidate Expiration Workflow', type: :feature do
  include ActiveJob::TestHelper

  let(:agent) { create(:user, :agent_user, email: 'agent@test.com') }
  let(:candidate) do
    create(:candidate,
           first_name: 'Jean',
           last_name: 'Dupont',
           position: 'Développeur Ruby',
           publication_status: :draft,
           agent: agent)
  end

  before do
    # Mock publishable? pour permettre la publication
    allow_any_instance_of(Candidate).to receive(:publishable?).and_return(true)
  end

  describe 'Complete 14-day expiration workflow' do
    it 'sends reminder at day 12 and auto-expires at day 14' do
      # J+0: Publication du candidat
      travel_to Time.zone.local(2025, 1, 1, 10, 0, 0) do
        candidate.publish_workflow!

        expect(candidate).to be_published
        expect(candidate.published_at).to eq(Time.current)
        expect(candidate.expires_at).to be_within(1.second).of(14.days.from_now)
        expect(candidate.expiration_notified_at).to be_nil
      end

      # J+1 à J+11: Rien ne se passe
      travel_to Time.zone.local(2025, 1, 8, 10, 0, 0) do
        CandidateExpirationReminderJob.new.perform

        candidate.reload
        expect(candidate).to be_published
        expect(candidate.expiration_notified_at).to be_nil
      end

      # J+12: Envoi de la notification (9h du matin)
      travel_to Time.zone.local(2025, 1, 13, 9, 0, 0) do
        # Vérifier que le candidat est dans le scope expiring_soon
        candidate.reload
        expiring = Candidate.expiring_soon
        expect(expiring).to include(candidate)

        # Mock le mailer pour vérifier l'envoi (deliver_now since we fixed race condition)
        allow(AgentMailer).to receive(:candidate_expiration_reminder)
          .with(candidate.id)
          .and_return(double(deliver_now: true))

        CandidateExpirationReminderJob.new.perform

        candidate.reload
        expect(candidate).to be_published
        expect(candidate.expiration_notified_at).not_to be_nil
        expect(candidate.expires_at).to be_within(1.second).of(Time.zone.local(2025, 1, 15, 10, 0, 0))
      end

      # J+13: Toujours publié, rien ne se passe
      travel_to Time.zone.local(2025, 1, 14, 10, 0, 0) do
        CandidateAutoExpirationJob.new.perform

        candidate.reload
        expect(candidate).to be_published
      end

      # J+14: Expiration automatique (après 10h)
      travel_to Time.zone.local(2025, 1, 15, 10, 30, 0) do
        CandidateAutoExpirationJob.new.perform

        candidate.reload
        expect(candidate).to be_draft
        expect(candidate.published_at).to be_nil
        expect(candidate.expires_at).to be_nil
        expect(candidate.expiration_notified_at).to be_nil
      end
    end

    it 'extends publication when agent clicks "Prolonger"' do
      # J+0: Publication
      travel_to Time.zone.local(2025, 1, 1, 10, 0, 0) do
        candidate.publish_workflow!
      end

      # J+12: Notification envoyée
      travel_to Time.zone.local(2025, 1, 13, 9, 0, 0) do
        candidate.update_column(:expiration_notified_at, Time.current)
      end

      # J+13: L'agent prolonge
      travel_to Time.zone.local(2025, 1, 14, 14, 0, 0) do
        candidate.extend_publication!

        candidate.reload
        expect(candidate).to be_published
        expect(candidate.expires_at).to be_within(1.second).of(14.days.from_now)
        expect(candidate.expiration_notified_at).to be_nil
      end

      # J+14: Le candidat ne doit PAS être expiré car prolongé
      travel_to Time.zone.local(2025, 1, 15, 10, 30, 0) do
        CandidateAutoExpirationJob.new.perform

        candidate.reload
        expect(candidate).to be_published # Toujours publié !
      end

      # J+26 (14 jours après prolongation): Nouvelle notification
      travel_to Time.zone.local(2025, 1, 27, 9, 0, 0) do
        expect(AgentMailer).to receive(:candidate_expiration_reminder)
          .with(candidate.id)
          .and_return(double(deliver_now: true))

        CandidateExpirationReminderJob.new.perform

        candidate.reload
        expect(candidate.expiration_notified_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'unpublishes immediately when agent clicks "Dépublier"' do
      # J+0: Publication
      travel_to Time.zone.local(2025, 1, 1, 10, 0, 0) do
        candidate.publish_workflow!
      end

      # J+12: Notification envoyée
      travel_to Time.zone.local(2025, 1, 13, 9, 0, 0) do
        candidate.update_column(:expiration_notified_at, Time.current)
      end

      # J+13: L'agent dépublie manuellement
      travel_to Time.zone.local(2025, 1, 14, 11, 0, 0) do
        candidate.unpublish_workflow!

        candidate.reload
        expect(candidate).to be_draft
        expect(candidate.published_at).to be_nil
        expect(candidate.expires_at).to be_nil
        expect(candidate.expiration_notified_at).to be_nil
      end
    end

    it 'does not send duplicate notifications' do
      # J+0: Publication
      travel_to Time.zone.local(2025, 1, 1, 10, 0, 0) do
        candidate.publish_workflow!
      end

      # J+12: Première notification
      travel_to Time.zone.local(2025, 1, 13, 9, 0, 0) do
        expect(AgentMailer).to receive(:candidate_expiration_reminder)
          .with(candidate.id)
          .once
          .and_return(double(deliver_now: true))

        CandidateExpirationReminderJob.new.perform

        candidate.reload
        expect(candidate.expiration_notified_at).not_to be_nil
      end

      # J+13: Le job tourne à nouveau mais ne doit PAS envoyer de mail
      travel_to Time.zone.local(2025, 1, 14, 9, 0, 0) do
        expect(AgentMailer).not_to receive(:candidate_expiration_reminder)

        CandidateExpirationReminderJob.new.perform
      end
    end

    it 'handles multiple candidates with different timelines' do
      candidate2 = create(:candidate,
                          first_name: 'Marie',
                          last_name: 'Martin',
                          position: 'Designer',
                          publication_status: :draft,
                          agent: agent)

      allow_any_instance_of(Candidate).to receive(:publishable?).and_return(true)

      # J+0: Publication du candidat 1
      travel_to Time.zone.local(2025, 1, 1, 10, 0, 0) do
        candidate.publish_workflow!
      end

      # J+5: Publication du candidat 2
      travel_to Time.zone.local(2025, 1, 6, 10, 0, 0) do
        candidate2.publish_workflow!
      end

      # J+12: Seul le candidat 1 doit recevoir une notification
      travel_to Time.zone.local(2025, 1, 13, 9, 0, 0) do
        allow(AgentMailer).to receive(:candidate_expiration_reminder).and_return(double(deliver_now: true))

        CandidateExpirationReminderJob.new.perform

        expect(candidate.reload.expiration_notified_at).not_to be_nil
        expect(candidate2.reload.expiration_notified_at).to be_nil
      end

      # J+15: Expiration automatique du candidat 1 uniquement
      travel_to Time.zone.local(2025, 1, 15, 10, 30, 0) do
        CandidateAutoExpirationJob.new.perform

        expect(candidate.reload).to be_draft
        expect(candidate2.reload).to be_published # Pas encore expiré
      end

      # J+17: Notification pour le candidat 2 (J+12 pour lui)
      travel_to Time.zone.local(2025, 1, 18, 9, 0, 0) do
        allow(AgentMailer).to receive(:candidate_expiration_reminder).and_return(double(deliver_now: true))

        CandidateExpirationReminderJob.new.perform

        expect(candidate2.reload.expiration_notified_at).not_to be_nil
      end

      # J+20: Expiration du candidat 2
      travel_to Time.zone.local(2025, 1, 20, 10, 30, 0) do
        CandidateAutoExpirationJob.new.perform

        expect(candidate2.reload).to be_draft
      end
    end
  end

  describe 'Edge cases' do
    it 'does not expire candidates that were never notified' do
      # J+0: Publication
      travel_to Time.zone.local(2025, 1, 1, 10, 0, 0) do
        candidate.publish_workflow!
      end

      # J+14: Le candidat a expiré mais n'a jamais été notifié (bug?)
      travel_to Time.zone.local(2025, 1, 15, 10, 30, 0) do
        # On s'assure qu'il n'a pas été notifié
        candidate.update_column(:expiration_notified_at, nil)

        CandidateAutoExpirationJob.new.perform

        candidate.reload
        expect(candidate).to be_published # Ne doit pas être expiré
      end
    end

    it 'does not notify draft candidates' do
      travel_to Time.zone.local(2025, 1, 1, 10, 0, 0) do
        # Candidat reste en draft
        expect(AgentMailer).not_to receive(:candidate_expiration_reminder)

        CandidateExpirationReminderJob.new.perform

        candidate.reload
        expect(candidate.expiration_notified_at).to be_nil
      end
    end
  end
end
