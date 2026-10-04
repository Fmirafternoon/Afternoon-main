require 'rails_helper'

RSpec.describe Resume::UpdateCandidate do
  let(:candidate) { create(:candidate) }
  let(:json_output) { {} }
  let(:actor_result) { described_class.call(candidate: candidate, json_output: json_output) }

  before do
    # Mock Resume::EmbedJob to prevent async job execution
    allow(Resume::EmbedJob).to receive(:perform_async)
  end

  describe '#call' do
    context 'with basic candidate information' do
      let(:json_output) do
        {
          "first_name" => "John",
          "last_name" => "Doe",
          "position" => "Software Developer",
          "gender" => "male",
          "description" => "Experienced developer",
          "birth_year" => 1990,
          "email" => "john.doe@example.com",
          "address" => "123 Main St",
          "phone_number" => "+33612345678",
          "total_experience_in_years" => 5,
          "has_driving_license" => true,
          "has_a_car" => false,
          "availability_notice" => "immediate",
          "contract_type" => "cdi",
          "salary_expectation" => "50000",
          "change_motivations" => "Career growth",
          "ongoing_applications" => { "quantité" => 3 },
          "career_relevance" => "Highly relevant"
        }
      end

      it 'updates the candidate with all basic fields' do
        actor_result
        candidate.reload

        expect(candidate.first_name).to eq("John")
        expect(candidate.last_name).to eq("Doe")
        expect(candidate.position).to eq("Software Developer")
        expect(candidate.gender).to eq("male")
        expect(candidate.description).to eq("Experienced developer")
        expect(candidate.birth_year).to eq(1990)
        expect(candidate.email).to eq("john.doe@example.com")
        expect(candidate.address).to eq("123 Main St")
        expect(candidate.phone_number).to eq("+33612345678")
        expect(candidate.total_experience_in_years).to eq(5)
        expect(candidate.has_driving_license).to be true
        expect(candidate.has_a_car).to be false
        expect(candidate.availability_notice).to eq("immediate")
        expect(candidate.contract_type).to eq("cdi")
        expect(candidate.salary_expectation).to eq(50000)
        expect(candidate.change_motivations).to eq("Career growth")
        expect(candidate.ongoing_application).to eq(true)
        expect(candidate.career_relevance).to eq("Highly relevant")
      end

      it 'triggers Resume::EmbedJob' do
        expect(Resume::EmbedJob).to receive(:perform_async).with(candidate.id)
        actor_result
      end
    end

    context 'with sectors' do
      let!(:sector1) { create(:sector, name: "IT") }
      let!(:sector2) { create(:sector, name: "Finance") }
      let(:json_output) do
        {
          "sectors" => [sector1.id, sector2.id]
        }
      end

      it 'updates candidate sectors' do
        # Create existing sector to test destroy_all
        existing_sector = create(:sector)
        candidate.sectors << existing_sector

        actor_result
        candidate.reload

        expect(candidate.sectors).to contain_exactly(sector1, sector2)
        expect(candidate.sectors).not_to include(existing_sector)
      end
    end

    context 'with skills' do
      let(:json_output) do
        {
          "skills" => [
            { "label" => "Ruby", "semantic" => "Programming language" },
            { "label" => "Rails", "semantic" => "Web framework" }
          ]
        }
      end

      it 'creates or finds skills and updates candidate skills' do
        actor_result
        candidate.reload

        expect(candidate.skills.map(&:name)).to contain_exactly("Ruby", "Rails")
        
        ruby_skill = Skill.find_by(name: "Ruby")
        expect(ruby_skill.semantic).to eq("Programming language")
      end

      it 'does not update semantic if skill already has one' do
        existing_skill = create(:skill, name: "Ruby", semantic: "Existing semantic")
        
        actor_result
        
        existing_skill.reload
        expect(existing_skill.semantic).to eq("Existing semantic")
      end

      it 'destroys existing candidate skills' do
        old_skill = create(:skill, name: "Python")
        candidate.skills << old_skill

        actor_result
        candidate.reload

        expect(candidate.skills).not_to include(old_skill)
      end
    end

    context 'with mobilities' do
      let(:json_output) do
        {
          "candidate_mobilities" => [
            { "city" => "Paris", "zip_code" => "75001" },
            { "city" => "Lyon", "zip_code" => "69001" }
          ]
        }
      end

      it 'creates locations and candidate mobilities' do
        actor_result
        candidate.reload

        expect(candidate.candidate_mobilities.count).to eq(2)
        
        locations = candidate.locations
        expect(locations.map(&:city)).to contain_exactly("Paris", "Lyon")
        expect(locations.map(&:zip_code)).to contain_exactly("75001", "69001")
      end

      it 'destroys existing mobilities' do
        old_location = create(:location, city: "Marseille")
        candidate.locations << old_location

        actor_result
        candidate.reload

        expect(candidate.locations).not_to include(old_location)
      end
    end

    context 'with languages' do
      let(:json_output) do
        {
          "languages" => [
            { "code" => "en", "level" => "C1" },
            { "code" => "fr", "level" => "C2" }
          ]
        }
      end

      it 'creates candidate languages' do
        actor_result
        candidate.reload

        expect(candidate.candidate_languages.count).to eq(2)
        
        languages = candidate.candidate_languages
        expect(languages.map(&:code)).to contain_exactly("en", "fr")
        expect(languages.map(&:level)).to contain_exactly("C1", "C2")
      end
    end

    context 'with employments' do
      let(:json_output) do
        {
          "employments" => [
            {
              "title" => "Senior Developer",
              "company" => "Tech Corp",
              "description" => "Lead development team",
              "location" => "Paris",
              "from" => { "year" => 2020, "month" => 1 },
              "to" => { "year" => 2024, "month" => 1 },
              "duration_in_months" => 48
            }
          ]
        }
      end

      it 'creates employments' do
        actor_result
        candidate.reload

        employment = candidate.employments.first
        expect(employment.title).to eq("Senior Developer")
        expect(employment.company).to eq("Tech Corp")
        expect(employment.description).to eq("Lead development team")
        expect(employment.location).to eq("Paris")
        expect(employment.from_year).to eq(2020)
        expect(employment.from_month).to eq(1)
        expect(employment.to_year).to eq(2024)
        expect(employment.to_month).to eq(1)
        expect(employment.duration_in_months).to eq(48)
      end
    end

    context 'with educations' do
      let(:json_output) do
        {
          "educations" => [
            {
              "title" => "Master in Computer Science",
              "issuing_organization" => "University of Paris",
              "location" => "Paris",
              "from" => { "year" => 2015, "month" => 9 },
              "to" => { "year" => 2017, "month" => 6 }
            }
          ]
        }
      end

      it 'creates educations' do
        actor_result
        candidate.reload

        education = candidate.educations.first
        expect(education.title).to eq("Master in Computer Science")
        expect(education.issuing_organization).to eq("University of Paris")
        expect(education.location).to eq("Paris")
        expect(education.from_year).to eq(2015)
        expect(education.from_month).to eq(9)
        expect(education.to_year).to eq(2017)
        expect(education.to_month).to eq(6)
      end
    end

    context 'with trainings' do
      let(:json_output) do
        {
          "trainings" => [
            {
              "description" => "AWS Certification",
              "issuing_organization" => "Amazon",
              "year" => 2022
            }
          ]
        }
      end

      it 'creates trainings' do
        actor_result
        candidate.reload

        training = candidate.trainings.first
        expect(training.title).to eq("AWS Certification")
        expect(training.issuing_organization).to eq("Amazon")
        expect(training.year).to eq(2022)
      end
    end

    context 'with referrals' do
      let(:json_output) do
        {
          "references" => [
            {
              "full_name" => "Jane Smith",
              "phone_number" => "+33687654321",
              "email" => "jane.smith@example.com",
              "company" => "Previous Corp",
              "position" => "Manager",
              "description" => "Great colleague"
            }
          ]
        }
      end

      it 'creates referrals' do
        actor_result
        candidate.reload

        referral = candidate.referrals.first
        expect(referral.first_name).to eq("Jane")
        expect(referral.last_name).to eq("Smith")
        expect(referral.phone_number).to eq("+33687654321")
        expect(referral.email).to eq("jane.smith@example.com")
        expect(referral.company).to eq("Previous Corp")
        expect(referral.position).to eq("Manager")
        expect(referral.description).to eq("Great colleague")
      end

      it 'handles single name correctly' do
        json_output["references"][0]["full_name"] = "Madonna"
        
        actor_result
        
        referral = candidate.referrals.first
        expect(referral.first_name).to eq("Madonna")
        expect(referral.last_name).to eq("")
      end
    end

    context 'with red flags' do
      let(:json_output) do
        {
          "red_flags" => {
            "too_many_jobs" => {
              "score" => 1,
              "question" => "Changed jobs frequently?",
              "optional" => "true"
            },
            "gap_in_employment" => {
              "score" => 0,
              "question" => "Employment gaps?",
              "optional" => "false"
            }
          }
        }
      end

      it 'creates red flags only with score 1' do
        actor_result
        candidate.reload

        expect(candidate.red_flags.count).to eq(1)
        
        red_flag = candidate.red_flags.first
        expect(red_flag.slug).to eq("too_many_jobs")
        expect(red_flag.score).to eq(1)
        expect(red_flag.question).to eq("Changed jobs frequently?")
        expect(red_flag.optional).to be true
      end

      it 'does not create red flags with score 0' do
        actor_result
        
        expect(candidate.red_flags.where(slug: "gap_in_employment")).to be_empty
      end
    end

    context 'with resume summary' do
      let(:json_output) do
        {
          "position" => "Software Developer", # Include position to avoid validation error
          "resume_summary" => {
            "skills" => "Ruby, Rails, JavaScript",
            "accomplishments" => "Led team of 5 developers",
            "management" => "Agile methodology",
            "specializations" => ["Backend development"],
            "security_qualifications" => ["OWASP certified"]
          }
        }
      end

      it 'updates resume summary' do
        actor_result
        candidate.reload

        expect(candidate.resume_summary).to eq({
          "skills" => "Ruby, Rails, JavaScript",
          "accomplishments" => "Led team of 5 developers",
          "management" => "Agile methodology",
          "specializations" => ["Backend development"],
          "security_qualifications" => ["OWASP certified"]
        })
      end
    end

    context 'with partial json output' do
      before do
        # Set initial values
        candidate.update!(
          first_name: "Initial",
          last_name: "Name",
          position: "Initial Position"
        )
      end

      let(:json_output) do
        {
          "first_name" => "Jane",
          "skills" => [{ "label" => "Python", "semantic" => "Language" }]
        }
      end

      it 'updates all basic fields (nil values overwrite existing)' do
        # The actor updates the candidate with all fields from json_output
        actor_result
        candidate.reload
        
        # Basic fields are updated with values from json_output (nil values overwrite existing)
        expect(candidate.first_name).to eq("Jane")
        expect(candidate.last_name).to be_nil  # last_name not in json_output, so becomes nil
        expect(candidate.position).to be_nil    # position not in json_output, so becomes nil
        # Skills are also updated
        expect(candidate.skills.map(&:name)).to eq(["Python"])
      end
    end

    context 'with empty arrays' do
      before do
        # Setup existing data
        candidate.sectors << create(:sector)
        candidate.skills << create(:skill)
        location = create(:location)
        candidate.locations << location
        
        # Ensure the data is persisted
        candidate.reload
        expect(candidate.sectors.count).to eq(1)
        expect(candidate.skills.count).to eq(1)
        expect(candidate.locations.count).to eq(1)
      end

      let(:json_output) do
        {
          "position" => "Developer", # Keep position to avoid validation failure
          "sectors" => [],
          "skills" => [],
          "candidate_mobilities" => []
        }
      end

      it 'does not update associations when arrays are empty (present? check)' do
        # The actor uses .present? which returns false for empty arrays
        # So empty arrays don't trigger updates - existing associations are preserved
        
        actor_result
        candidate.reload

        # Associations remain unchanged because empty arrays are not "present"
        expect(candidate.sectors.count).to eq(1)
        expect(candidate.skills.count).to eq(1)
        expect(candidate.locations.count).to eq(1)
      end
    end

    context 'when explicitly wanting to clear associations' do
      before do
        # Setup existing data
        candidate.sectors << create(:sector)
        candidate.skills << create(:skill)
      end

      it 'preserves existing associations when fields are not provided' do
        json_output = { "position" => "Developer" }

        actor_result = described_class.call(candidate: candidate, json_output: json_output)
        candidate.reload

        # Since sectors and skills keys are not in json_output, they remain unchanged
        expect(candidate.sectors.count).to eq(1)
        expect(candidate.skills.count).to eq(1)
      end
    end

    context 'transaction rollback on error' do
      let(:json_output) do
        {
          "first_name" => "John",
          "last_name" => "Doe",
          "position" => "Developer"
        }
      end

      before do
        # Initialize candidate with some data
        candidate.update!(first_name: "Original", position: "Original Position")
      end

      it 'rolls back all changes if candidate update fails' do
        # Mock a validation error on candidate update
        allow(candidate).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new)

        expect {
          described_class.call(candidate: candidate, json_output: json_output)
        }.to raise_error(ActiveRecord::RecordInvalid)

        candidate.reload

        # Verify rollback: all original data should be preserved
        expect(candidate.first_name).to eq("Original")
        expect(candidate.position).to eq("Original Position")
      end

      it 'does not execute EmbedJob if transaction fails' do
        allow(candidate).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)

        expect(Resume::EmbedJob).not_to receive(:perform_async)

        expect {
          described_class.call(candidate: candidate, json_output: json_output)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'executes EmbedJob only after successful transaction' do
        expect(Resume::EmbedJob).to receive(:perform_async).with(candidate.id)

        described_class.call(candidate: candidate, json_output: json_output)
      end
    end

    context 'transaction behavior with nested operations' do
      let(:json_output) do
        {
          "first_name" => "Jane",
          "position" => "Senior Developer",
          "skills" => [{ "label" => "Ruby", "semantic" => "Language" }],
          "employments" => [
            {
              "title" => "Developer",
              "company" => "Tech Corp",
              "description" => "Coding",
              "from" => { "year" => 2020, "month" => 1 },
              "to" => { "year" => 2024, "month" => 1 }
            }
          ]
        }
      end

      it 'rolls back candidate update and all associations on failure' do
        candidate.update!(first_name: "Original")

        # Force a failure during employment creation
        allow_any_instance_of(Employment).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)

        expect {
          described_class.call(candidate: candidate, json_output: json_output)
        }.to raise_error(ActiveRecord::RecordInvalid)

        candidate.reload

        # All changes should be rolled back
        expect(candidate.first_name).to eq("Original")
        expect(candidate.position).not_to eq("Senior Developer")
        expect(candidate.skills).to be_empty
        expect(candidate.employments).to be_empty
      end

      it 'commits all changes if transaction succeeds' do
        candidate.update!(first_name: "Original")

        described_class.call(candidate: candidate, json_output: json_output)
        candidate.reload

        # All changes should be committed
        expect(candidate.first_name).to eq("Jane")
        expect(candidate.position).to eq("Senior Developer")
        expect(candidate.skills.pluck(:name)).to eq(["Ruby"])
        expect(candidate.employments.count).to eq(1)
        expect(candidate.employments.first.title).to eq("Developer")
      end
    end
  end
end