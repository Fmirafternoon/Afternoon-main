require 'rails_helper'

RSpec.describe WizardHelper, type: :helper do
  describe '#wizard_breadcrumb_options' do
    let(:wizard_steps) { [:step1, :step2, :step3, :step4] }
    let(:current_step) { :step2 }
    let(:key) { 'candidate_wizard' }
    let(:description) { 'Création du profil candidat' }

    let(:params) do
      {
        key: key,
        wizard_steps: wizard_steps,
        current_step: current_step,
        description: description
      }
    end

    before do
      # Define the methods that would be provided by the controller/view context
      def helper.step_path(step)
        "/wizard/#{step}"
      end

      def helper.step_accessible?(step)
        true
      end
    end

    it 'returns a hash with all required keys' do
      result = helper.wizard_breadcrumb_options(**params)

      expect(result).to be_a(Hash)
      expect(result).to have_key(:key)
      expect(result).to have_key(:wizard_steps)
      expect(result).to have_key(:current_step)
      expect(result).to have_key(:description)
      expect(result).to have_key(:step_path)
      expect(result).to have_key(:step_accessible)
    end

    it 'passes through the key parameter' do
      result = helper.wizard_breadcrumb_options(**params)
      expect(result[:key]).to eq(key)
    end

    it 'passes through the wizard_steps parameter' do
      result = helper.wizard_breadcrumb_options(**params)
      expect(result[:wizard_steps]).to eq(wizard_steps)
    end

    it 'passes through the current_step parameter' do
      result = helper.wizard_breadcrumb_options(**params)
      expect(result[:current_step]).to eq(current_step)
    end

    it 'passes through the description parameter' do
      result = helper.wizard_breadcrumb_options(**params)
      expect(result[:description]).to eq(description)
    end

    describe 'step_path lambda' do
      it 'returns a callable lambda' do
        result = helper.wizard_breadcrumb_options(**params)
        expect(result[:step_path]).to be_a(Proc)
        expect(result[:step_path]).to respond_to(:call)
      end

            it 'calls step_path method when lambda is executed' do
        result = helper.wizard_breadcrumb_options(**params)
        path_result = result[:step_path].call(:step1)

        expect(path_result).to eq('/wizard/step1')
      end

      it 'works with different step parameters' do
        result = helper.wizard_breadcrumb_options(**params)
        path_result = result[:step_path].call(:custom_step)

        expect(path_result).to eq('/wizard/custom_step')
      end
    end

    describe 'step_accessible lambda' do
      it 'returns a callable lambda' do
        result = helper.wizard_breadcrumb_options(**params)
        expect(result[:step_accessible]).to be_a(Proc)
        expect(result[:step_accessible]).to respond_to(:call)
      end

            it 'calls step_accessible? method when lambda is executed' do
        result = helper.wizard_breadcrumb_options(**params)
        accessible_result = result[:step_accessible].call(:step1)

        expect(accessible_result).to be true
      end

      it 'works with different step parameters' do
        # Override the method for this specific test
        def helper.step_accessible?(step)
          step != :step3
        end

        result = helper.wizard_breadcrumb_options(**params)
        accessible_result = result[:step_accessible].call(:step3)

        expect(accessible_result).to be false
      end

      it 'handles edge cases' do
        # Override the method for this specific test
        def helper.step_accessible?(step)
          !step.nil?
        end

        result = helper.wizard_breadcrumb_options(**params)
        accessible_result = result[:step_accessible].call(nil)

        expect(accessible_result).to be false
      end
    end

    context 'with different parameter combinations' do
      it 'works with string steps' do
        string_steps = ['step1', 'step2', 'step3']
        params_with_strings = params.merge(
          wizard_steps: string_steps,
          current_step: 'step2'
        )

        result = helper.wizard_breadcrumb_options(**params_with_strings)

        expect(result[:wizard_steps]).to eq(string_steps)
        expect(result[:current_step]).to eq('step2')
      end

      it 'works with numeric steps' do
        numeric_steps = [1, 2, 3, 4]
        params_with_numbers = params.merge(
          wizard_steps: numeric_steps,
          current_step: 2
        )

        result = helper.wizard_breadcrumb_options(**params_with_numbers)

        expect(result[:wizard_steps]).to eq(numeric_steps)
        expect(result[:current_step]).to eq(2)
      end

      it 'works with empty description' do
        params_empty_desc = params.merge(description: '')

        result = helper.wizard_breadcrumb_options(**params_empty_desc)

        expect(result[:description]).to eq('')
      end

      it 'works with nil description' do
        params_nil_desc = params.merge(description: nil)

        result = helper.wizard_breadcrumb_options(**params_nil_desc)

        expect(result[:description]).to be_nil
      end
    end

    context 'integration scenarios' do
            it 'creates a complete configuration for breadcrumb component' do
        # Simulate real wizard scenario
        candidate_steps = [:personal_info, :skills, :experience, :availability]

        result = helper.wizard_breadcrumb_options(
          key: 'candidate_creation',
          wizard_steps: candidate_steps,
          current_step: :personal_info,
          description: 'Création du profil candidat'
        )

        # Test that all parts work together
        expect(result[:key]).to eq('candidate_creation')
        expect(result[:wizard_steps]).to eq(candidate_steps)
        expect(result[:current_step]).to eq(:personal_info)
        expect(result[:description]).to eq('Création du profil candidat')

        # Test lambdas work
        path = result[:step_path].call(:personal_info)
        accessible = result[:step_accessible].call(:personal_info)

        expect(path).to eq('/wizard/personal_info')
        expect(accessible).to be true
      end
    end

        context 'error handling' do
      it 'handles errors in step_path method gracefully' do
        # Redefine method to raise error
        def helper.step_path(step)
          raise StandardError, "Path generation failed"
        end

        result = helper.wizard_breadcrumb_options(**params)

        expect {
          result[:step_path].call(:step1)
        }.to raise_error(StandardError, "Path generation failed")
      end

      it 'handles errors in step_accessible? method gracefully' do
        # Redefine method to raise error
        def helper.step_accessible?(step)
          raise StandardError, "Accessibility check failed"
        end

        result = helper.wizard_breadcrumb_options(**params)

        expect {
          result[:step_accessible].call(:step1)
        }.to raise_error(StandardError, "Accessibility check failed")
      end
    end
  end
end
