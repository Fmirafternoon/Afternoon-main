require 'rails_helper'

RSpec.describe Candidate::MotivationsForm do
  let(:candidate) { create(:candidate, publication_status: 'draft') }
  let(:form) { described_class.new(attributes) }
  let(:attributes) { { id: candidate.id } }

  describe '#initialize' do
    it 'finds the candidate by id' do
      expect(form.instance_variable_get(:@candidate)).to eq(candidate)
    end

    it 'handles indifferent access for id' do
      form = described_class.new('id' => candidate.id)
      expect(form.instance_variable_get(:@candidate)).to eq(candidate)
    end

    it 'raises error when candidate not found' do
      expect {
        described_class.new(id: 999999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'validations' do
    describe 'required fields' do
      it 'requires position' do
        form = described_class.new(id: candidate.id, description: 'A' * 300)
        expect(form).not_to be_valid
        expect(form.errors[:position]).to include("doit être rempli(e)")
      end

      it 'requires description' do
        form = described_class.new(id: candidate.id, position: 'Developer')
        expect(form).not_to be_valid
        expect(form.errors[:description]).to include("doit être rempli(e)")
      end
    end

    describe 'description length' do
      let(:base_attributes) do
        {
          id: candidate.id,
          position: 'Software Engineer'
        }
      end

      it 'allows a short description' do
        form = described_class.new(base_attributes.merge(description: 'Profil solide.'))
        expect(form).to be_valid
      end

      it 'allows description of 500 characters' do
        form = described_class.new(base_attributes.merge(description: 'A' * 500))
        expect(form).to be_valid
      end

      it 'requires description to be at most 500 characters' do
        form = described_class.new(base_attributes.merge(description: 'A' * 501))
        expect(form).not_to be_valid
        expect(form.errors[:description]).to include("est trop long (pas plus de 500 caractères)")
      end
    end

    describe 'optional field length limits' do
      let(:valid_attributes) do
        {
          id: candidate.id,
          position: 'Senior Developer',
          description: 'A' * 300
        }
      end

      it 'allows change_motivations up to 500 characters' do
        form = described_class.new(valid_attributes.merge(change_motivations: 'A' * 500))
        expect(form).to be_valid
      end

      it 'rejects change_motivations over 500 characters' do
        form = described_class.new(valid_attributes.merge(change_motivations: 'A' * 501))
        expect(form).not_to be_valid
        expect(form.errors[:change_motivations]).to include("est trop long (pas plus de 500 caractères)")
      end

      it 'allows career_relevance up to 500 characters' do
        form = described_class.new(valid_attributes.merge(career_relevance: 'A' * 500))
        expect(form).to be_valid
      end

      it 'rejects career_relevance over 500 characters' do
        form = described_class.new(valid_attributes.merge(career_relevance: 'A' * 501))
        expect(form).not_to be_valid
        expect(form.errors[:career_relevance]).to include("est trop long (pas plus de 500 caractères)")
      end
    end

    describe 'optional fields' do
      let(:valid_attributes) do
        {
          id: candidate.id,
          position: 'Senior Developer',
          description: 'A' * 300
        }
      end

      it 'does not require total_experience_in_years' do
        form = described_class.new(valid_attributes)
        expect(form).to be_valid
      end

      it 'does not require ongoing_application' do
        form = described_class.new(valid_attributes)
        expect(form).to be_valid
      end

      it 'does not require change_motivations' do
        form = described_class.new(valid_attributes)
        expect(form).to be_valid
      end

      it 'does not require career_relevance' do
        form = described_class.new(valid_attributes)
        expect(form).to be_valid
      end
    end
  end

  describe '#save' do
    context 'when form is valid' do
      let(:valid_attributes) do
        {
          id: candidate.id,
          position: 'Full Stack Developer',
          total_experience_in_years: 5,
          description: 'I am a passionate developer with 5 years of experience in web development. I have worked on various projects including e-commerce platforms, SaaS applications, and mobile apps. My expertise includes Ruby on Rails, JavaScript, React, and PostgreSQL. I am looking for new challenges to grow my skills and advance my career.',
          ongoing_application: true,
          change_motivations: 'Looking for better work-life balance and more challenging projects',
          career_relevance: 'This position aligns perfectly with my career goals'
        }
      end

      it 'updates the candidate' do
        form = described_class.new(valid_attributes)
        expect(form.save).to be true
        
        candidate.reload
        expect(candidate.position).to eq('Full Stack Developer')
        expect(candidate.total_experience_in_years).to eq(5)
        expect(candidate.description).to eq(valid_attributes[:description])
        expect(candidate.ongoing_application).to be true
        expect(candidate.change_motivations).to eq('Looking for better work-life balance and more challenging projects')
        expect(candidate.career_relevance).to eq('This position aligns perfectly with my career goals')
      end

      it 'returns true' do
        form = described_class.new(valid_attributes)
        expect(form.save).to be true
      end

      context 'with minimal attributes' do
        let(:minimal_attributes) do
          {
            id: candidate.id,
            position: 'Developer',
            description: 'A' * 300
          }
        end

        it 'updates candidate with minimal data' do
          form = described_class.new(minimal_attributes)
          expect(form.save).to be true
          
          candidate.reload
          expect(candidate.position).to eq('Developer')
          expect(candidate.description).to eq('A' * 300)
        end
      end

      context 'with boolean values' do
        it 'handles false value for ongoing_application' do
          form = described_class.new(
            id: candidate.id,
            position: 'Developer',
            description: 'A' * 300,
            ongoing_application: false
          )
          
          expect(form.save).to be true
          expect(candidate.reload.ongoing_application).to be false
        end

        it 'handles true value for ongoing_application' do
          form = described_class.new(
            id: candidate.id,
            position: 'Developer',
            description: 'A' * 300,
            ongoing_application: true
          )
          
          expect(form.save).to be true
          expect(candidate.reload.ongoing_application).to be true
        end
      end
    end

    context 'when form is invalid' do
      let(:invalid_attributes) do
        {
          id: candidate.id,
          position: '',
          description: ''
        }
      end

      it 'does not update candidate' do
        original_position = candidate.position
        form = described_class.new(invalid_attributes)
        
        expect(form.save).to be false
        expect(candidate.reload.position).to eq(original_position)
      end

      it 'returns false' do
        form = described_class.new(invalid_attributes)
        expect(form.save).to be false
      end

      it 'populates errors' do
        form = described_class.new(invalid_attributes)
        form.save
        
        expect(form.errors[:position]).to be_present
        expect(form.errors[:description]).to be_present
      end
    end
  end

  describe 'private methods' do
    describe '#persist!' do
      context 'with existing candidate id' do
        let(:attributes) do
          {
            id: candidate.id,
            position: 'Senior Engineer',
            description: 'A' * 350,
            total_experience_in_years: 8
          }
        end

        it 'finds and updates the candidate' do
          form = described_class.new(attributes)
          form.send(:persist!)
          
          candidate.reload
          expect(candidate.position).to eq('Senior Engineer')
          expect(candidate.total_experience_in_years).to eq(8)
        end

        it 'excludes id from attributes when updating' do
          form = described_class.new(attributes)
          
          # Mock to verify what attributes are passed
          allow_any_instance_of(Candidate).to receive(:assign_attributes) do |_, attrs|
            expect(attrs).not_to have_key('id')
            expect(attrs).not_to have_key(:id)
          end
          
          form.send(:persist!)
        end
      end

      context 'without id (new candidate)' do
        let(:user) { create(:user, :agent_user) }
        
        before do
          allow(Current).to receive(:user).and_return(user)
        end

        it 'creates a new candidate for current user' do
          # The form always requires an existing candidate ID in initialize,
          # but persist! can create a new candidate when id is nil
          form = described_class.new(id: candidate.id)
          form.id = nil  # Set the id attribute to nil, not the instance variable
          form.position = 'Junior Developer'
          form.description = 'A' * 300
          
          expect {
            form.send(:persist!)
          }.to change { user.candidates.count }.by(1)
          
          new_candidate = user.candidates.last
          expect(new_candidate.position).to eq('Junior Developer')
          expect(form.id).to eq(new_candidate.id)
        end
      end

      it 'raises error if save fails' do
        form = described_class.new(id: candidate.id)
        
        # Make save! fail
        allow_any_instance_of(Candidate).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(candidate))
        
        expect {
          form.send(:persist!)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe 'edge cases' do
    describe 'nil and empty values' do
      let(:base_attributes) do
        {
          id: candidate.id,
          position: 'Developer',
          description: 'A' * 300
        }
      end

      it 'handles nil values for optional fields' do
        form = described_class.new(base_attributes.merge(
          total_experience_in_years: nil,
          ongoing_application: nil,
          change_motivations: nil,
          career_relevance: nil
        ))
        
        expect(form).to be_valid
        form.save
        
        candidate.reload
        expect(candidate.total_experience_in_years).to be_nil
        expect(candidate.ongoing_application).to be_nil
        expect(candidate.change_motivations).to be_nil
        expect(candidate.career_relevance).to be_nil
      end

      it 'handles empty strings for text fields' do
        form = described_class.new(base_attributes.merge(
          change_motivations: '',
          career_relevance: ''
        ))
        
        expect(form).to be_valid
        form.save
        
        candidate.reload
        expect(candidate.change_motivations).to eq('')
        expect(candidate.career_relevance).to eq('')
      end
    end

    describe 'integer values' do
      it 'handles zero for total_experience_in_years' do
        form = described_class.new(
          id: candidate.id,
          position: 'Junior Developer',
          description: 'A' * 300,
          total_experience_in_years: 0
        )
        
        expect(form).to be_valid
        form.save
        
        expect(candidate.reload.total_experience_in_years).to eq(0)
      end

      it 'handles large values for total_experience_in_years' do
        form = described_class.new(
          id: candidate.id,
          position: 'Senior Architect',
          description: 'A' * 300,
          total_experience_in_years: 30
        )
        
        expect(form).to be_valid
        form.save
        
        expect(candidate.reload.total_experience_in_years).to eq(30)
      end
    end
  end

  describe 'model_class' do
    it 'is set to Candidate' do
      expect(described_class.model_class).to eq(Candidate)
    end
  end
end