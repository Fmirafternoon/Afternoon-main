require 'rails_helper'

RSpec.describe SectorCardComponent, type: :component do
  describe '#initialize' do
    it 'sets the required attributes' do
      component = described_class.new(
        title: 'Technology',
        image_url: '/assets/tech.jpg'
      )
      
      expect(component.instance_variable_get(:@title)).to eq('Technology')
      expect(component.instance_variable_get(:@image_url)).to eq('/assets/tech.jpg')
      expect(component.instance_variable_get(:@description)).to be_nil
      expect(component.instance_variable_get(:@button_text)).to be_nil
      expect(component.instance_variable_get(:@button_link)).to be_nil
    end

    it 'sets all attributes when provided' do
      component = described_class.new(
        title: 'Technology',
        image_url: '/assets/tech.jpg',
        description: 'Join our tech team',
        button_text: 'Apply Now',
        button_link: '/jobs/tech'
      )
      
      expect(component.instance_variable_get(:@title)).to eq('Technology')
      expect(component.instance_variable_get(:@image_url)).to eq('/assets/tech.jpg')
      expect(component.instance_variable_get(:@description)).to eq('Join our tech team')
      expect(component.instance_variable_get(:@button_text)).to eq('Apply Now')
      expect(component.instance_variable_get(:@button_link)).to eq('/jobs/tech')
    end
  end

  describe '#with_action?' do
    context 'when all action attributes are present' do
      it 'returns true' do
        component = described_class.new(
          title: 'Technology',
          image_url: '/assets/tech.jpg',
          description: 'Join our tech team',
          button_text: 'Apply Now',
          button_link: '/jobs/tech'
        )
        
        expect(component.with_action?).to be true
      end
    end

    context 'when description is missing' do
      it 'returns false' do
        component = described_class.new(
          title: 'Technology',
          image_url: '/assets/tech.jpg',
          button_text: 'Apply Now',
          button_link: '/jobs/tech'
        )
        
        expect(component.with_action?).to be false
      end
    end

    context 'when button_text is missing' do
      it 'returns false' do
        component = described_class.new(
          title: 'Technology',
          image_url: '/assets/tech.jpg',
          description: 'Join our tech team',
          button_link: '/jobs/tech'
        )
        
        expect(component.with_action?).to be false
      end
    end

    context 'when button_link is missing' do
      it 'returns false' do
        component = described_class.new(
          title: 'Technology',
          image_url: '/assets/tech.jpg',
          description: 'Join our tech team',
          button_text: 'Apply Now'
        )
        
        expect(component.with_action?).to be false
      end
    end

    context 'when no action attributes are present' do
      it 'returns false' do
        component = described_class.new(
          title: 'Technology',
          image_url: '/assets/tech.jpg'
        )
        
        expect(component.with_action?).to be false
      end
    end
  end

  describe '#css_classes' do
    context 'when component has action' do
      it 'includes group class' do
        component = described_class.new(
          title: 'Technology',
          image_url: '/assets/tech.jpg',
          description: 'Join our tech team',
          button_text: 'Apply Now',
          button_link: '/jobs/tech'
        )
        
        expect(component.css_classes).to eq('relative rounded-[18px] overflow-hidden shadow-md h-[320px] md:h-[480px] group')
      end
    end

    context 'when component does not have action' do
      it 'does not include group class' do
        component = described_class.new(
          title: 'Technology',
          image_url: '/assets/tech.jpg'
        )
        
        expect(component.css_classes).to eq('relative rounded-[18px] overflow-hidden shadow-md h-[320px] md:h-[480px]')
      end
    end
  end

  describe 'rendering' do
    let(:controller) { ApplicationController.new }
    let(:view_context) { controller.view_context }

    context 'with action' do
      it 'renders the component with action elements' do
        component = described_class.new(
          title: 'Technology',
          image_url: '/assets/tech.jpg',
          description: 'Join our tech team',
          button_text: 'Apply Now',
          button_link: '/jobs/tech'
        )
        
        rendered = component.render_in(view_context)
        
        expect(rendered).to include('class="relative rounded-[18px] overflow-hidden shadow-md h-[320px] md:h-[480px] group"')
        expect(rendered).to include('src="/assets/tech.jpg"')
        expect(rendered).to include('alt="Technology"')
        expect(rendered).to include('Technology')
        expect(rendered).to include('Recruter')
        expect(rendered).to include('un collaborateur dans le')
        expect(rendered).to include('Apply Now')
        expect(rendered).to include('href="/jobs/tech"')
        expect(rendered).to include('target="_blank"')
      end
    end

    context 'without action' do
      it 'renders the component without action elements' do
        component = described_class.new(
          title: 'Healthcare',
          image_url: '/assets/health.jpg'
        )
        
        rendered = component.render_in(view_context)
        
        expect(rendered).to include('class="relative rounded-[18px] overflow-hidden shadow-md h-[320px] md:h-[480px]"')
        expect(rendered).not_to include('class="relative rounded-[18px] overflow-hidden shadow-md h-[320px] md:h-[480px] group"')
        expect(rendered).to include('src="/assets/health.jpg"')
        expect(rendered).to include('alt="Healthcare"')
        expect(rendered).to include('Healthcare')
        expect(rendered).not_to include('Recruter')
        expect(rendered).not_to include('<a')
      end
    end

    context 'with special characters in title' do
      it 'properly escapes HTML' do
        component = described_class.new(
          title: 'Arts & Culture',
          image_url: '/assets/arts.jpg'
        )
        
        rendered = component.render_in(view_context)
        
        expect(rendered).to include('Arts &amp; Culture')
        expect(rendered).to include('alt="Arts &amp; Culture"')
      end
    end

    context 'with full URL for image' do
      it 'renders the image with full URL' do
        component = described_class.new(
          title: 'Remote Work',
          image_url: 'https://example.com/remote.jpg'
        )
        
        rendered = component.render_in(view_context)
        
        expect(rendered).to include('src="https://example.com/remote.jpg"')
      end
    end

    it 'includes all styling classes' do
      component = described_class.new(
        title: 'Finance',
        image_url: '/assets/finance.jpg'
      )
      
      rendered = component.render_in(view_context)
      
      expect(rendered).to include('relative')
      expect(rendered).to include('rounded-[18px]')
      expect(rendered).to include('overflow-hidden')
      expect(rendered).to include('shadow-md')
      expect(rendered).to include('h-[320px]')
      expect(rendered).to include('md:h-[480px]')
      expect(rendered).to include('bg-gradient-to-t')
      expect(rendered).to include('from-black/70')
      expect(rendered).to include('to-transparent')
    end

    it 'renders hover state classes for action cards' do
      component = described_class.new(
        title: 'Marketing',
        image_url: '/assets/marketing.jpg',
        description: 'Join marketing',
        button_text: 'Join Us',
        button_link: '/careers'
      )
      
      rendered = component.render_in(view_context)
      
      expect(rendered).to include('group-hover:opacity-0')
      expect(rendered).to include('group-hover:opacity-100')
      expect(rendered).to include('group-hover:translate-y-0')
      expect(rendered).to include('group-hover:scale-[2]')
    end
  end
end