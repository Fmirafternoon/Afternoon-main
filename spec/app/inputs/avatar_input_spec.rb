
require 'rails_helper'

RSpec.describe AvatarInput, type: :input do
  let(:object) { double('object', avatar: nil) }
  let(:template) do
    double('template',
      content_tag: '<div class="image-picker">Déposer l\'image</div>',
      concat: nil,
      safe_join: nil
    )
  end
  let(:builder) { double('builder', object: object, template: template) }
  let(:input) { AvatarInput.new(builder, :avatar, nil, {}, {}) }

  describe '#input' do
    it 'retourne du HTML avec la classe image-picker' do
      html = input.input
      expect(html).to include('image-picker')
      expect(html).to match(/Déposer l[’']image/)
    end
  end
end
