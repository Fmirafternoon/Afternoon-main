require 'rails_helper'

RSpec.describe CandidateExpirationsController, type: :controller do
  let(:agent) { create(:user, :agent_user) }
  let(:candidate) do
    create(:candidate,
           publication_status: :published,
           published_at: 12.days.ago,
           expires_at: 2.days.from_now,
           expiration_notified_at: 1.day.ago,
           agent: agent)
  end

  describe 'GET #extend' do
    context 'with valid token' do
      let(:valid_token) do
        Rails.application.message_verifier(:candidate_expiration).generate({
          candidate_id: candidate.id,
          action: 'extend',
          expires_at: 30.days.from_now
        })
      end

      it 'extends the candidate publication' do
        get :extend_publication, params: { token: valid_token }
        expect(candidate.reload.expires_at).to be_within(5.seconds).of(14.days.from_now)
      end

      it 'resets expiration_notified_at' do
        get :extend_publication, params: { token: valid_token }
        expect(candidate.reload.expiration_notified_at).to be_nil
      end

      it 'redirects to root with success message' do
        get :extend_publication, params: { token: valid_token }
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Publication prolongée de 14 jours')
      end

      it 'keeps the candidate published' do
        get :extend_publication, params: { token: valid_token }
        expect(candidate.reload).to be_published
      end
    end

    context 'with expired token' do
      let(:expired_token) do
        Rails.application.message_verifier(:candidate_expiration).generate({
          candidate_id: candidate.id,
          action: 'extend',
          expires_at: 1.day.ago
        })
      end

      it 'does not extend the publication' do
        original_expires_at = candidate.expires_at
        get :extend_publication, params: { token: expired_token }
        expect(candidate.reload.expires_at).to eq(original_expires_at)
      end

      it 'redirects with error message' do
        get :extend_publication, params: { token: expired_token }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Lien invalide ou expiré')
      end
    end

    context 'with invalid token' do
      it 'does not extend the publication' do
        original_expires_at = candidate.expires_at
        get :extend_publication, params: { token: 'invalid_token' }
        expect(candidate.reload.expires_at).to eq(original_expires_at)
      end

      it 'redirects with error message' do
        get :extend_publication, params: { token: 'invalid_token' }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Lien invalide ou expiré')
      end
    end

    context 'when candidate does not exist' do
      let(:valid_token) do
        Rails.application.message_verifier(:candidate_expiration).generate({
          candidate_id: 999999,
          action: 'extend',
          expires_at: 30.days.from_now
        })
      end

      it 'redirects with error message' do
        get :extend_publication, params: { token: valid_token }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Lien invalide ou expiré')
      end
    end
  end

  describe 'GET #unpublish' do
    context 'with valid token' do
      let(:valid_token) do
        Rails.application.message_verifier(:candidate_expiration).generate({
          candidate_id: candidate.id,
          action: 'unpublish',
          expires_at: 30.days.from_now
        })
      end

      it 'unpublishes the candidate' do
        expect(candidate).to be_published
        get :unpublish, params: { token: valid_token }
        expect(candidate.reload).to be_draft
      end

      it 'clears publication data' do
        get :unpublish, params: { token: valid_token }
        candidate.reload
        expect(candidate.published_at).to be_nil
        expect(candidate.expires_at).to be_nil
        expect(candidate.expiration_notified_at).to be_nil
      end

      it 'redirects to root with success message' do
        get :unpublish, params: { token: valid_token }
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Candidat dépublié avec succès')
      end
    end

    context 'with expired token' do
      let(:expired_token) do
        Rails.application.message_verifier(:candidate_expiration).generate({
          candidate_id: candidate.id,
          action: 'unpublish',
          expires_at: 1.day.ago
        })
      end

      it 'does not unpublish the candidate' do
        get :unpublish, params: { token: expired_token }
        expect(candidate.reload).to be_published
      end

      it 'redirects with error message' do
        get :unpublish, params: { token: expired_token }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Lien invalide ou expiré')
      end
    end

    context 'with invalid token' do
      it 'does not unpublish the candidate' do
        get :unpublish, params: { token: 'invalid_token' }
        expect(candidate.reload).to be_published
      end

      it 'redirects with error message' do
        get :unpublish, params: { token: 'invalid_token' }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Lien invalide ou expiré')
      end
    end

    context 'when candidate cannot be unpublished' do
      let(:draft_candidate) { create(:candidate, publication_status: :draft, agent: agent) }
      let(:valid_token) do
        Rails.application.message_verifier(:candidate_expiration).generate({
          candidate_id: draft_candidate.id,
          action: 'unpublish',
          expires_at: 30.days.from_now
        })
      end

      it 'does not change candidate status' do
        get :unpublish, params: { token: valid_token }
        expect(draft_candidate.reload).to be_draft
      end

      it 'redirects with error message' do
        get :unpublish, params: { token: valid_token }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Action impossible')
      end
    end

    context 'when candidate does not exist' do
      let(:valid_token) do
        Rails.application.message_verifier(:candidate_expiration).generate({
          candidate_id: 999999,
          action: 'unpublish',
          expires_at: 30.days.from_now
        })
      end

      it 'redirects with error message' do
        get :unpublish, params: { token: valid_token }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Lien invalide ou expiré')
      end
    end
  end

  describe 'authentication' do
    it 'does not require user authentication' do
      valid_token = Rails.application.message_verifier(:candidate_expiration).generate({
        candidate_id: candidate.id,
        action: 'extend',
        expires_at: 30.days.from_now
      })

      get :extend_publication, params: { token: valid_token }
      expect(response).not_to redirect_to(new_user_session_path)
    end
  end
end
