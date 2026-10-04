require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe Resume::EmbedJob, type: :job do
  let(:candidate) { create(:candidate, position: "Software Engineer") }
  let(:job) { described_class.new }
  let(:embedding) { Array.new(1536) { rand } } # Typical embedding size
  
  before do
    Sidekiq::Testing.inline!
  end

  after do
    Sidekiq::Testing.fake!
  end

  describe '#perform' do
    context 'with successful embedding creation' do
      before do
        # Mock Candidate.find
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        
        # Mock Embedding::Create actor
        embedding_result = double('EmbeddingResult', embedding: embedding)
        allow(Embedding::Create).to receive(:call).and_return(embedding_result)
        
        # Mock candidate update
        allow(candidate).to receive(:update)
      end

      it 'finds the candidate' do
        expect(Candidate).to receive(:find).with(candidate.id)
        job.perform(candidate.id)
      end

      context 'without resume summary' do
        before do
          allow(candidate).to receive(:resume_summary).and_return(nil)
        end

        it 'calls Embedding::Create with position only' do
          expect(Embedding::Create).to receive(:call).with(
            text: ["Software Engineer", "Software Engineer"]
          )
          job.perform(candidate.id)
        end

        it 'updates candidate with embedding' do
          expect(candidate).to receive(:update).with(job_title_embedding: embedding)
          job.perform(candidate.id)
        end
      end

      context 'with empty resume summary' do
        before do
          allow(candidate).to receive(:resume_summary).and_return({})
        end

        it 'calls Embedding::Create with position only' do
          expect(Embedding::Create).to receive(:call).with(
            text: ["Software Engineer", "Software Engineer"]
          )
          job.perform(candidate.id)
        end
      end

      context 'with resume summary' do
        let(:resume_summary) do
          {
            "skills" => ["Ruby", "Rails", "JavaScript"],
            "experience" => "5 years in web development",
            "education" => "Computer Science degree",
            "languages" => ["English", "French"],
            "certifications" => ""
          }
        end

        before do
          allow(candidate).to receive(:resume_summary).and_return(resume_summary)
        end

        it 'calls Embedding::Create with position and formatted summary' do
          expected_text = [
            "Software Engineer",
            "Software Engineer",
            "Skills : Ruby, Rails, JavaScript",
            "Experience : 5 years in web development",
            "Education : Computer Science degree",
            "Languages : English, French"
          ]
          
          expect(Embedding::Create).to receive(:call).with(text: expected_text)
          job.perform(candidate.id)
        end

        it 'skips empty values in resume summary' do
          job.perform(candidate.id)
          
          # Verify certifications (empty string) was not included
          expect(Embedding::Create).to have_received(:call) do |args|
            expect(args[:text]).not_to include("Certifications : ")
          end
        end

        it 'updates candidate with embedding' do
          expect(candidate).to receive(:update).with(job_title_embedding: embedding)
          job.perform(candidate.id)
        end
      end

      context 'with complex resume summary' do
        let(:resume_summary) do
          {
            "skills" => ["Ruby on Rails", "PostgreSQL", "Redis"],
            "experience" => "Senior developer with 10 years experience",
            "education" => nil,
            "projects" => ["E-commerce platform", "API development"],
            "interests" => "",
            "achievements" => ["Team lead", "Open source contributor"]
          }
        end

        before do
          allow(candidate).to receive(:resume_summary).and_return(resume_summary)
        end

        it 'handles nil values correctly' do
          job.perform(candidate.id)
          
          # Verify education (nil) was not included
          expect(Embedding::Create).to have_received(:call) do |args|
            expect(args[:text]).not_to include("Education")
          end
        end

        it 'formats array values with comma separation' do
          job.perform(candidate.id)
          
          expect(Embedding::Create).to have_received(:call) do |args|
            expect(args[:text]).to include("Skills : Ruby on Rails, PostgreSQL, Redis")
            expect(args[:text]).to include("Projects : E-commerce platform, API development")
            expect(args[:text]).to include("Achievements : Team lead, Open source contributor")
          end
        end
      end

      context 'with different positions' do
        it 'uses the candidate position in the embedding text' do
          candidate.position = "Data Scientist"
          allow(candidate).to receive(:resume_summary).and_return({})
          
          expect(Embedding::Create).to receive(:call).with(
            text: ["Data Scientist", "Data Scientist"]
          )
          job.perform(candidate.id)
        end
      end
    end

    context 'when candidate not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          job.perform(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when Embedding::Create returns empty embedding' do
      before do
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        
        # Mock failed embedding
        embedding_result = double('EmbeddingResult', embedding: [])
        allow(Embedding::Create).to receive(:call).and_return(embedding_result)
        
        allow(candidate).to receive(:update)
      end

      it 'raises and does not update the candidate' do
        expect(candidate).not_to receive(:update)
        expect {
          job.perform(candidate.id)
        }.to raise_error(/Embedding vide/)
      end
    end

    context 'error handling' do
      before do
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
      end

      it 'does not rescue Embedding::Create errors' do
        allow(Embedding::Create).to receive(:call).and_raise(StandardError.new('API error'))
        
        expect {
          job.perform(candidate.id)
        }.to raise_error(StandardError, 'API error')
      end

      it 'does not rescue update errors' do
        embedding_result = double('EmbeddingResult', embedding: embedding)
        allow(Embedding::Create).to receive(:call).and_return(embedding_result)
        allow(candidate).to receive(:update).and_raise(ActiveRecord::RecordInvalid)
        
        expect {
          job.perform(candidate.id)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#resume_summary_as_sentences' do
    let(:job_instance) { described_class.new }

    before do
      job_instance.instance_variable_set(:@candidate, candidate)
    end

    it 'returns empty array when resume_summary is nil' do
      allow(candidate).to receive(:resume_summary).and_return(nil)
      
      result = job_instance.send(:resume_summary_as_sentences)
      expect(result).to eq([])
    end

    it 'returns empty array when resume_summary is blank' do
      allow(candidate).to receive(:resume_summary).and_return("")
      
      result = job_instance.send(:resume_summary_as_sentences)
      expect(result).to eq([])
    end

    it 'formats hash values correctly' do
      resume_summary = {
        "technical_skills" => ["Python", "Machine Learning"],
        "soft_skills" => "Communication and leadership"
      }
      allow(candidate).to receive(:resume_summary).and_return(resume_summary)
      
      result = job_instance.send(:resume_summary_as_sentences)
      expect(result).to eq([
        "Technical skills : Python, Machine Learning",
        "Soft skills : Communication and leadership"
      ])
    end

    it 'humanizes keys properly' do
      resume_summary = {
        "years_of_experience" => "10",
        "preferred_location" => "Remote"
      }
      allow(candidate).to receive(:resume_summary).and_return(resume_summary)
      
      result = job_instance.send(:resume_summary_as_sentences)
      expect(result).to eq([
        "Years of experience : 10",
        "Preferred location : Remote"
      ])
    end

    it 'handles mixed value types' do
      resume_summary = {
        "string_value" => "Test",
        "array_value" => ["Item1", "Item2"],
        "empty_string" => "",
        "empty_array" => [],
        "nil_value" => nil
      }
      allow(candidate).to receive(:resume_summary).and_return(resume_summary)
      
      result = job_instance.send(:resume_summary_as_sentences)
      expect(result).to eq([
        "String value : Test",
        "Array value : Item1, Item2"
      ])
    end
  end

  describe 'Sidekiq configuration' do
    it 'includes Sidekiq::Job' do
      expect(described_class.ancestors).to include(Sidekiq::Job)
    end

    it 'can be enqueued' do
      Sidekiq::Testing.fake! do
        expect {
          described_class.perform_async(candidate.id)
        }.to change(described_class.jobs, :size).by(1)
      end
    end

    it 'enqueues with correct arguments' do
      Sidekiq::Testing.fake! do
        described_class.perform_async(candidate.id)
        
        job = described_class.jobs.last
        expect(job['args']).to eq([candidate.id])
      end
    end
  end

  describe 'integration with Embedding::Create' do
    it 'passes text array to Embedding::Create' do
      allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
      allow(candidate).to receive(:resume_summary).and_return({ "skills" => ["Ruby"] })
      allow(candidate).to receive(:update)
      
      expect(Embedding::Create).to receive(:call) do |args|
        expect(args[:text]).to be_an(Array)
        expect(args[:text].first).to eq(candidate.position)
      end.and_return(double(embedding: embedding))
      
      job.perform(candidate.id)
    end
  end
end