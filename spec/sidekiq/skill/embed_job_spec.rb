require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe Skill::EmbedJob, type: :job do
  let(:skill) do
    # Mock the job to prevent it from being enqueued during test setup
    allow(Skill::EmbedJob).to receive(:perform_async).and_return(nil)
    create(:skill, name: "Ruby on Rails", semantic: ["web development", "framework", "MVC"])
  end
  let(:job) { described_class.new }
  let(:embedding) { Array.new(1024) { rand } }
  
  before do
    Sidekiq::Testing.inline!
  end

  after do
    Sidekiq::Testing.fake!
  end

  describe '#perform' do
    context 'with successful embedding creation' do
      before do
        # Mock Skill.find
        allow(Skill).to receive(:find).with(skill.id).and_return(skill)
        
        # Mock Embedding::Create actor
        embedding_result = double('EmbeddingResult', embedding: embedding)
        allow(Embedding::Create).to receive(:call).and_return(embedding_result)
        
        # Mock skill update
        allow(skill).to receive(:update!)
      end

      it 'finds the skill' do
        expect(Skill).to receive(:find).with(skill.id)
        job.perform(skill.id)
      end

      it 'calls Embedding::Create with skill name and semantic' do
        expect(Embedding::Create).to receive(:call).with(
          text: ["Ruby on Rails", "web development, framework, MVC"]
        )
        job.perform(skill.id)
      end

      it 'updates skill with embedding' do
        expect(skill).to receive(:update!).with(embedding: embedding)
        job.perform(skill.id)
      end

      context 'with different skills' do
        it 'handles skill with empty semantic array' do
          skill.semantic = []
          allow(skill).to receive(:semantic).and_return([])
          
          expect(Embedding::Create).to receive(:call).with(
            text: ["Ruby on Rails", ""]
          )
          job.perform(skill.id)
        end

        it 'handles skill with single semantic value' do
          skill.semantic = ["programming"]
          allow(skill).to receive(:semantic).and_return(["programming"])
          
          expect(Embedding::Create).to receive(:call).with(
            text: ["Ruby on Rails", "programming"]
          )
          job.perform(skill.id)
        end

        it 'handles skill with many semantic values' do
          skill.semantic = ["backend", "API", "REST", "GraphQL", "microservices"]
          allow(skill).to receive(:semantic).and_return(["backend", "API", "REST", "GraphQL", "microservices"])
          
          expect(Embedding::Create).to receive(:call).with(
            text: ["Ruby on Rails", "backend, API, REST, GraphQL, microservices"]
          )
          job.perform(skill.id)
        end

        it 'handles skill with special characters in name' do
          skill.name = "C++"
          allow(skill).to receive(:name).and_return("C++")
          
          expect(Embedding::Create).to receive(:call).with(
            text: ["C++", "web development, framework, MVC"]
          )
          job.perform(skill.id)
        end

        it 'handles skill with unicode in semantic' do
          skill.semantic = ["développement", "ingénierie", "programmation"]
          allow(skill).to receive(:semantic).and_return(["développement", "ingénierie", "programmation"])
          
          expect(Embedding::Create).to receive(:call).with(
            text: ["Ruby on Rails", "développement, ingénierie, programmation"]
          )
          job.perform(skill.id)
        end
      end

      context 'with nil semantic' do
        before do
          allow(skill).to receive(:semantic).and_return(nil)
        end

        it 'raises error when semantic is nil' do
          expect {
            job.perform(skill.id)
          }.to raise_error(NoMethodError)
        end
      end
    end

    context 'when skill not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          job.perform(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when Embedding::Create returns empty embedding' do
      before do
        allow(Skill).to receive(:find).with(skill.id).and_return(skill)

        # Mock failed embedding
        embedding_result = double('EmbeddingResult', embedding: [])
        allow(Embedding::Create).to receive(:call).and_return(embedding_result)
      end

      it 'raises an error for empty embedding' do
        expect {
          job.perform(skill.id)
        }.to raise_error(RuntimeError, /Embedding vide retourné pour Skill##{skill.id}/)
      end
    end

    context 'error handling' do
      before do
        allow(Skill).to receive(:find).with(skill.id).and_return(skill)
      end

      it 'does not rescue Embedding::Create errors' do
        allow(Embedding::Create).to receive(:call).and_raise(StandardError.new('API error'))
        
        expect {
          job.perform(skill.id)
        }.to raise_error(StandardError, 'API error')
      end

      it 'does not rescue update errors' do
        embedding_result = double('EmbeddingResult', embedding: embedding)
        allow(Embedding::Create).to receive(:call).and_return(embedding_result)
        allow(skill).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)

        expect {
          job.perform(skill.id)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'with database constraints' do
      before do
        allow(Skill).to receive(:find).with(skill.id).and_return(skill)
        embedding_result = double('EmbeddingResult', embedding: embedding)
        allow(Embedding::Create).to receive(:call).and_return(embedding_result)
      end

      it 'handles validation errors on update' do
        allow(skill).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(skill))

        expect {
          job.perform(skill.id)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe 'Sidekiq configuration' do
    before do
      # Remove the mock for these tests
      allow(Skill::EmbedJob).to receive(:perform_async).and_call_original
    end

    it 'includes Sidekiq::Job' do
      expect(described_class.ancestors).to include(Sidekiq::Job)
    end

    it 'can be enqueued' do
      Sidekiq::Testing.fake! do
        expect {
          described_class.perform_async(123)
        }.to change(described_class.jobs, :size).by(1)
      end
    end

    it 'enqueues with correct arguments' do
      Sidekiq::Testing.fake! do
        described_class.perform_async(123)
        
        job = described_class.jobs.last
        expect(job['args']).to eq([123])
      end
    end
  end

  describe 'integration with Embedding::Create' do
    it 'passes text array to Embedding::Create' do
      allow(Skill).to receive(:find).with(skill.id).and_return(skill)
      allow(skill).to receive(:update!)

      expect(Embedding::Create).to receive(:call) do |args|
        expect(args[:text]).to be_an(Array)
        expect(args[:text].size).to eq(2)
        expect(args[:text][0]).to eq(skill.name)
        expect(args[:text][1]).to be_a(String)
      end.and_return(double(embedding: embedding))
      
      job.perform(skill.id)
    end
  end

  describe 'after_create_commit hook' do
    it 'is triggered when creating a new skill', enable_callbacks: true do
      # Set up expectation before clearing the mock
      expect(Skill::EmbedJob).to receive(:perform_async).once
      
      create(:skill, name: "Python")
    end
  end

  describe 'instance variable assignment' do
    it 'assigns skill to instance variable' do
      allow(Skill).to receive(:find).with(skill.id).and_return(skill)
      embedding_result = double('EmbeddingResult', embedding: embedding)
      allow(Embedding::Create).to receive(:call).and_return(embedding_result)
      allow(skill).to receive(:update!)
      
      job.perform(skill.id)
      
      expect(job.instance_variable_get(:@skill)).to eq(skill)
    end
  end
end