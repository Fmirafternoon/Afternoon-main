require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe Project::EmailBroadcastJob, type: :job do
  let(:paris) { create(:location, city: "Paris", latitude: 48.8566, longitude: 2.3522) }
  let(:versailles) { create(:location, city: "Versailles", zip_code: "78000", latitude: 48.8049, longitude: 2.1204) }
  let(:lyon) { create(:location, city: "Lyon", zip_code: "69001", latitude: 45.7640, longitude: 4.8357) }

  let(:project) { create(:project, :broadcast_enabled, location: paris) }

  let(:nearby_office) { create(:recruitment_office, location: versailles) }
  let(:far_office) { create(:recruitment_office, location: lyon) }

  let!(:nearby_agent) { create(:user, :agent_user, recruitment_office: nearby_office) }
  let!(:far_agent) { create(:user, :agent_user, recruitment_office: far_office) }

  let(:job) { described_class.new }
  let(:mail_delivery) { double('MailDelivery', deliver_later: true) }

  before do
    allow(AgentMailer).to receive(:project_broadcast).and_return(mail_delivery)
  end

  describe '#perform' do
    it 'emails the agents of offices within 50 km' do
      job.perform(project.id)

      expect(AgentMailer).to have_received(:project_broadcast).with(nearby_agent.id, project.id)
    end

    it 'does not email agents of offices beyond 50 km' do
      job.perform(project.id)

      expect(AgentMailer).not_to have_received(:project_broadcast).with(far_agent.id, project.id)
    end

    it 'does not email agents of discarded offices' do
      discarded_office = create(:recruitment_office, :discarded, location: versailles)
      discarded_agent = create(:user, :agent_user, recruitment_office: discarded_office)

      job.perform(project.id)

      expect(AgentMailer).not_to have_received(:project_broadcast).with(discarded_agent.id, project.id)
    end

    it 'fills last_email_broadcasted_at' do
      expect {
        job.perform(project.id)
      }.to change { project.reload.last_email_broadcasted_at }.from(nil)
    end

    context 'when broadcast is disabled on the project' do
      let(:project) { create(:project, location: paris) }

      it 'sends nothing' do
        job.perform(project.id)
        expect(AgentMailer).not_to have_received(:project_broadcast)
      end
    end

    context 'when the project was broadcasted less than a week ago' do
      let(:project) do
        create(:project, :broadcast_enabled, location: paris, last_email_broadcasted_at: 2.days.ago)
      end

      it 'sends nothing' do
        job.perform(project.id)
        expect(AgentMailer).not_to have_received(:project_broadcast)
      end

      it 'does not change last_email_broadcasted_at' do
        expect {
          job.perform(project.id)
        }.not_to change { project.reload.last_email_broadcasted_at }
      end
    end

    context 'when the project was broadcasted more than a week ago' do
      let(:project) do
        create(:project, :broadcast_enabled, location: paris, last_email_broadcasted_at: 2.weeks.ago)
      end

      it 'sends the emails again' do
        job.perform(project.id)
        expect(AgentMailer).to have_received(:project_broadcast).with(nearby_agent.id, project.id)
      end
    end

    context 'when no office is nearby' do
      let(:project) { create(:project, :broadcast_enabled, location: lyon) }
      let!(:far_agent) { nil }

      it 'does not fill last_email_broadcasted_at so a later attempt stays possible' do
        job.perform(project.id)
        expect(project.reload.last_email_broadcasted_at).to be_nil
      end
    end

    context 'when the project location has no coordinates' do
      let(:city_only) { create(:location, city: "Paris", zip_code: nil, latitude: nil, longitude: nil) }
      let(:project) { create(:project, :broadcast_enabled, location: city_only) }

      it 'geocodes the location before searching offices' do
        geocode_result = double('GeocodeResult', location: paris)
        allow(Location::Geocode).to receive(:result)
          .with(address: city_only.full_address).and_return(geocode_result)

        job.perform(project.id)

        expect(AgentMailer).to have_received(:project_broadcast).with(nearby_agent.id, project.id)
      end

      it 'sends nothing when geocoding fails' do
        geocode_result = double('GeocodeResult', location: nil)
        allow(Location::Geocode).to receive(:result).and_return(geocode_result)

        job.perform(project.id)

        expect(AgentMailer).not_to have_received(:project_broadcast)
        expect(project.reload.last_email_broadcasted_at).to be_nil
      end
    end

    context 'when the project has no location' do
      let(:project) { create(:project, :broadcast_enabled, location: nil) }

      it 'sends nothing' do
        job.perform(project.id)
        expect(AgentMailer).not_to have_received(:project_broadcast)
      end
    end
  end
end
