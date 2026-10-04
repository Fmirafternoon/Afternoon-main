require 'rails_helper'

RSpec.describe Candidate::AvailabilityComponent, type: :component do
  let(:candidate) { create(:candidate) }
  
  describe '#initialize' do
    it 'sets the candidate and kind' do
      component = described_class.new(candidate: candidate)
      
      expect(component.candidate).to eq(candidate)
      expect(component.instance_variable_get(:@kind)).to eq(:success)
    end
  end

  describe '#render?' do
    context 'when candidate has availability notice' do
      it 'returns true' do
        candidate.availability_notice = 'immediate'
        component = described_class.new(candidate: candidate)
        
        expect(component.render?).to be true
      end
    end

    context 'when candidate has no availability notice' do
      it 'returns false' do
        candidate.availability_notice = nil
        component = described_class.new(candidate: candidate)
        
        expect(component.render?).to be false
      end
    end

    context 'when candidate has empty availability notice' do
      it 'returns false' do
        candidate.availability_notice = ''
        component = described_class.new(candidate: candidate)
        
        expect(component.render?).to be false
      end
    end
  end

  describe '#content' do
    let(:component) { described_class.new(candidate: candidate) }

    context 'with immediate availability' do
      it 'returns immediate text with emoji' do
        candidate.availability_notice = 'immediate'
        expect(component.content).to eq('⚡️ Immédiat')
      end
    end

    context 'with two_to_three_weeks availability' do
      it 'returns 2-3 weeks text with emoji' do
        candidate.availability_notice = 'two_to_three_weeks'
        expect(component.content).to eq('🕑 2 à 3 semaines')
      end
    end

    context 'with four_to_six_weeks availability' do
      it 'returns 4-6 weeks text with emoji' do
        candidate.availability_notice = 'four_to_six_weeks'
        expect(component.content).to eq('🕑 4 à 6 semaines')
      end
    end

    context 'with two_months availability' do
      it 'returns 2 months text with emoji' do
        candidate.availability_notice = 'two_months'
        expect(component.content).to eq('🗓️ 2 mois')
      end
    end

    context 'with three_months availability' do
      it 'returns 3 months text with emoji' do
        candidate.availability_notice = 'three_months'
        expect(component.content).to eq('🗓️ 3 mois')
      end
    end

    context 'with four_months_plus availability' do
      it 'returns 4 months+ text with emoji' do
        candidate.availability_notice = 'four_months_plus'
        expect(component.content).to eq('🗓️4 mois et plus')
      end
    end

    context 'with nil availability notice' do
      it 'returns nil' do
        candidate.availability_notice = nil
        expect(component.content).to be_nil
      end
    end
  end

  describe '#classes' do
    it 'returns the custom classes' do
      component = described_class.new(candidate: candidate)
      expect(component.classes).to eq('border border-mute-400 bg-mute-300 text-black')
    end
  end

  describe 'rendering' do
    let(:controller) { ApplicationController.new }
    let(:view_context) { controller.view_context }

    context 'when candidate has availability notice' do
      it 'renders the component with immediate availability' do
        candidate.availability_notice = 'immediate'
        component = described_class.new(candidate: candidate)
        
        rendered = component.render_in(view_context)
        
        expect(rendered).to include('⚡️ Immédiat')
        expect(rendered).to include('border border-mute-400 bg-mute-300 text-black')
        expect(rendered).to include('inline-flex min-h-5.5 items-center py-0.5 px-2 rounded-md paragraph-xs')
      end

      it 'renders the component with two months availability' do
        candidate.availability_notice = 'two_months'
        component = described_class.new(candidate: candidate)
        
        rendered = component.render_in(view_context)
        
        expect(rendered).to include('🗓️ 2 mois')
      end
    end

    context 'when candidate has no availability notice' do
      it 'does not render anything' do
        candidate.availability_notice = nil
        component = described_class.new(candidate: candidate)
        
        rendered = component.render_in(view_context)
        
        expect(rendered.to_s.strip).to be_empty
      end
    end
  end

  describe 'inheritance' do
    it 'inherits from TagComponent' do
      expect(described_class).to be < TagComponent
    end

    it 'uses parent class template' do
      candidate.availability_notice = 'immediate'
      component = described_class.new(candidate: candidate)
      controller = ApplicationController.new
      view_context = controller.view_context
      
      rendered = component.render_in(view_context)
      
      # Should use TagComponent's template with div wrapper
      expect(rendered).to include('<div class="inline-flex')
    end
  end
end