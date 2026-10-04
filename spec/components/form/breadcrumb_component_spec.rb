require 'rails_helper'

RSpec.describe Form::BreadcrumbComponent, type: :component do
  let(:wizard) { 'candidate_form' }
  let(:wizard_steps) { [:personal_info, :professional_info, :documents] }
  let(:current_step) { :professional_info }
  let(:description) { 'Please complete your professional information' }
  let(:step_path) { ->(step) { "/wizard/#{step}" } }
  let(:step_accessible) { ->(step) { wizard_steps.index(step) <= wizard_steps.index(current_step) } }

  describe '#initialize' do
    it 'sets all attributes' do
      component = described_class.new(
        wizard: wizard,
        wizard_steps: wizard_steps,
        current_step: current_step,
        description: description,
        step_path: step_path,
        step_accessible: step_accessible
      )
      
      expect(component.wizard).to eq(wizard)
      expect(component.wizard_steps).to eq(wizard_steps)
      expect(component.current_step).to eq(current_step)
      expect(component.description).to eq(description)
      expect(component.step_path).to eq(step_path)
      expect(component.step_accessible).to eq(step_accessible)
    end

    it 'works with minimal attributes' do
      component = described_class.new(
        wizard: wizard,
        wizard_steps: wizard_steps,
        current_step: current_step
      )
      
      expect(component.wizard).to eq(wizard)
      expect(component.wizard_steps).to eq(wizard_steps)
      expect(component.current_step).to eq(current_step)
      expect(component.description).to be_nil
      expect(component.step_path).to be_nil
      expect(component.step_accessible).to be_nil
    end
  end

  describe 'rendering' do
    let(:controller) { ApplicationController.new }
    let(:view_context) { controller.view_context }
    
    before do
      # Mock translations
      allow(I18n).to receive(:t).with("wizard.candidate_form.personal_info").and_return("Personal Information")
      allow(I18n).to receive(:t).with("wizard.candidate_form.professional_info").and_return("Professional Information")
      allow(I18n).to receive(:t).with("wizard.candidate_form.documents").and_return("Documents")
      
      # Mock inline_svg_tag helper
      allow(view_context).to receive(:inline_svg_tag) do |path, options|
        "<svg class=\"#{options[:class]}\"></svg>"
      end
    end

    context 'with all attributes' do
      it 'renders the current step number and description' do
        component = described_class.new(
          wizard: wizard,
          wizard_steps: wizard_steps,
          current_step: current_step,
          description: description,
          step_path: step_path,
          step_accessible: step_accessible
        )
        
        rendered = component.render_in(view_context)
        
        expect(rendered).to include('Étape 2')
        expect(rendered).to include(description)
      end

      it 'renders all wizard steps' do
        component = described_class.new(
          wizard: wizard,
          wizard_steps: wizard_steps,
          current_step: current_step,
          description: description,
          step_path: step_path,
          step_accessible: step_accessible
        )
        
        rendered = component.render_in(view_context)
        
        expect(rendered).to include('Personal Information')
        expect(rendered).to include('Professional Information')
        expect(rendered).to include('Documents')
      end

      it 'renders accessible steps as links' do
        component = described_class.new(
          wizard: wizard,
          wizard_steps: wizard_steps,
          current_step: current_step,
          description: description,
          step_path: step_path,
          step_accessible: step_accessible
        )
        
        rendered = component.render_in(view_context)
        
        # Personal info and professional info should be links (accessible)
        expect(rendered).to include('href="/wizard/personal_info"')
        expect(rendered).to include('href="/wizard/professional_info"')
        
        # Documents should not be a link (not accessible yet)
        expect(rendered).not_to include('href="/wizard/documents"')
      end

      it 'includes correct check icons' do
        component = described_class.new(
          wizard: wizard,
          wizard_steps: wizard_steps,
          current_step: current_step,
          description: description,
          step_path: step_path,
          step_accessible: step_accessible
        )
        
        rendered = component.render_in(view_context)
        
        # Check that SVGs are in the output (3 steps = 3 SVGs)
        expect(rendered.scan('<svg').count).to eq(3)
        # Check that completed steps have correct SVG styling
        expect(rendered).to include('class="mt-1 w-5 text-neutral-800"')
        # Check that non-completed steps have different SVG styling  
        expect(rendered).to include('class="mt-1 w-5 text-mute-400"')
      end
    end

    context 'without optional attributes' do
      it 'renders steps as non-clickable text' do
        component = described_class.new(
          wizard: wizard,
          wizard_steps: wizard_steps,
          current_step: current_step
        )
        
        rendered = component.render_in(view_context)
        
        # All steps should be rendered as h3 tags, not links
        expect(rendered).to include('<h3 class="title-5 text-neutral-800 normal-case">')
        expect(rendered).not_to include('href=')
      end

      it 'still shows step titles' do
        component = described_class.new(
          wizard: wizard,
          wizard_steps: wizard_steps,
          current_step: current_step
        )
        
        rendered = component.render_in(view_context)
        
        expect(rendered).to include('Personal Information')
        expect(rendered).to include('Professional Information')
        expect(rendered).to include('Documents')
      end
    end

    context 'with first step as current' do
      it 'shows step 1' do
        component = described_class.new(
          wizard: wizard,
          wizard_steps: wizard_steps,
          current_step: :personal_info,
          description: 'First step description'
        )
        
        rendered = component.render_in(view_context)
        
        expect(rendered).to include('Étape 1')
      end
    end

    context 'with last step as current' do
      it 'shows correct step number' do
        component = described_class.new(
          wizard: wizard,
          wizard_steps: wizard_steps,
          current_step: :documents,
          description: 'Last step description'
        )
        
        rendered = component.render_in(view_context)
        
        expect(rendered).to include('Étape 3')
      end
    end

    context 'with custom step accessibility logic' do
      it 'respects the step_accessible callback' do
        # Only first step is accessible
        custom_accessible = ->(step) { step == :personal_info }
        
        component = described_class.new(
          wizard: wizard,
          wizard_steps: wizard_steps,
          current_step: :professional_info,
          step_path: step_path,
          step_accessible: custom_accessible
        )
        
        rendered = component.render_in(view_context)
        
        expect(rendered).to include('href="/wizard/personal_info"')
        expect(rendered).not_to include('href="/wizard/professional_info"')
        expect(rendered).not_to include('href="/wizard/documents"')
      end
    end

    it 'includes correct CSS classes' do
      component = described_class.new(
        wizard: wizard,
        wizard_steps: wizard_steps,
        current_step: current_step,
        description: description
      )
      
      rendered = component.render_in(view_context)
      
      expect(rendered).to include('title-3 mb-2')
      expect(rendered).to include('paragraph-sm text-mute-900 mb-6')
      expect(rendered).to include('flex items-start mb-4 space-x-2.5')
    end
  end
end