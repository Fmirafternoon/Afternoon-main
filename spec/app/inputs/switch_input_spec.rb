require 'rails_helper'

RSpec.describe SwitchInput, type: :input do
  let(:object) { double('object', switch: nil) }
  let(:template) do
    double('template',
      content_tag: '<div class="relative inline-flex items-center cursor-pointer"></div>',
      concat: nil,
      safe_join: nil
    )
  end
  let(:builder) do
    double('builder',
      object: object,
      template: template,
      label: '<label class="relative inline-flex items-center cursor-pointer"><input type="checkbox" /><div class="absolute left-0.5 top-0.5 size-5 bg-white rounded-full shadow-sm transform transition peer-checked:translate-x-5"></div><div class="w-11 h-6 bg-mute-400 peer-checked:bg-success-500 rounded-full border border-mute-500 peer-checked:border-success-600 transition-colors duration-200 ease-in-out"></div></label>',
      check_box: '<input type="checkbox" />'
    )
  end
  let(:input) { SwitchInput.new(builder, :switch, nil, {}, {}) }

  describe '#input' do
    it 'retourne du HTML avec la classe relative inline-flex' do
      html = input.input
      expect(html).to include('relative inline-flex items-center cursor-pointer')
    end
  end
end
