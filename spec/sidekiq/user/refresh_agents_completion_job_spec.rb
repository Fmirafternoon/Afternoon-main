require 'rails_helper'

RSpec.describe User::RefreshAgentsCompletionJob, type: :job do
  let(:job) { described_class.new }

  describe '#perform' do
    it 'refreshes the average completion of every agent' do
      agent = create(:user, :agent_user)
      candidate = create(:candidate, agent: agent, publication_status: :published)
      candidate.update_column(:completion_percentage, 35)

      job.perform

      expect(agent.reload.average_completion_percentage).to eq(35)
    end

    it 'leaves non-agent users untouched' do
      customer = create(:user, :customer)

      job.perform

      expect(customer.reload.average_completion_percentage).to be_nil
    end

    it 'continues with the next agent when one fails' do
      agent1 = create(:user, :agent_user)
      agent2 = create(:user, :agent_user)
      candidate = create(:candidate, agent: agent2, publication_status: :published)
      candidate.update_column(:completion_percentage, 80)

      allow_any_instance_of(User).to receive(:recalculate_average_completion_percentage!)
        .and_wrap_original do |method, *args|
          raise "boom" if method.receiver.id == agent1.id
          method.call(*args)
        end

      expect { job.perform }.not_to raise_error
      expect(agent2.reload.average_completion_percentage).to eq(80)
    end
  end
end
