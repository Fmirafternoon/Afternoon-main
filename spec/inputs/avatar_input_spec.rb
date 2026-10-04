require 'rails_helper'

RSpec.describe AvatarInput do
  let(:object) { double('object', avatar: avatar_url, errors: {}) }
  let(:builder) { SimpleForm::FormBuilder.new(:user, object, template, {}) }
  let(:template) { ActionController::Base.new.view_context }
  let(:attribute_name) { :avatar }
  let(:column) { double('column') }
  let(:input_type) { :file }
  let(:options) { {} }
  
  subject(:input) { described_class.new(builder, attribute_name, column, input_type, options) }

  before do
    # Allow builder to work with our double object
    allow(builder).to receive(:object).and_return(object)
  end

  describe '#input' do
    context 'when object has no image' do
      let(:avatar_url) { nil }

      it 'returns a content tag with image picker' do
        result = input.input
        expect(result).to include('image-picker')
        expect(result).to include('data-controller="image-picker"')
      end

      it 'shows the upload hint' do
        result = input.input
        expect(result).to include('Déposer l&#39;image')
        expect(result).to include('Parcourir vos fichiers')
      end

      it 'includes the file input field' do
        result = input.input
        expect(result).to include('data-image-picker-target="input"')
        expect(result).to include('data-action="image-picker#preview"')
      end

      it 'includes the hidden url field' do
        result = input.input
        expect(result).to include('data-image-picker-target="urlField"')
      end

      it 'includes the keep field' do
        result = input.input
        expect(result).to include('data-image-picker-target="keep"')
      end

      it 'hides the preview when no image' do
        result = input.input
        expect(result).to include('class="preview w-20 h-20 bg-cover bg-center rounded-full border-2 border-gray-200 hidden"')
      end

      it 'hides the remove button when no image' do
        result = input.input
        expect(result).to include('class="remove absolute -top-2 -right-2 w-6 h-6 bg-red-500 text-white rounded-full flex items-center justify-center cursor-pointer hover:bg-red-600 text-sm hidden"')
      end
    end

    context 'when object has an image' do
      let(:avatar_url) { 'https://example.com/avatar.jpg' }

      it 'hides the upload hint' do
        result = input.input
        expect(result).to include('class="flex flex-col items-center justify-center text-center text-mute-700 hidden"')
      end

      it 'shows the preview with image URL' do
        result = input.input
        expect(result).to include("style='background-image: url(#{avatar_url})'")
        expect(result).not_to include('class="preview w-20 h-20 bg-cover bg-center rounded-full border-2 border-gray-200 hidden"')
      end

      it 'shows the remove button' do
        result = input.input
        expect(result).not_to include('class="remove absolute -top-2 -right-2 w-6 h-6 bg-red-500 text-white rounded-full flex items-center justify-center cursor-pointer hover:bg-red-600 text-sm hidden"')
        expect(result).to include('data-action="click->image-picker#remove"')
      end
    end
  end

  describe '#input_url_field' do
    let(:avatar_url) { nil }

    it 'creates a hidden field for the URL' do
      result = input.input_url_field({})
      expect(result).to include('type="hidden"')
      expect(result).to include('data-image-picker-target="urlField"')
    end
  end

  describe '#input_field' do
    let(:avatar_url) { nil }

    it 'creates a file field with proper attributes' do
      result = input.input_field({})
      expect(result).to include('type="file"')
      expect(result).to include('data-image-picker-target="input"')
      expect(result).to include('data-action="image-picker#preview"')
      expect(result).to include('class="opacity-0 inset-0 absolute"')
    end
  end

  describe '#keep_field' do
    let(:avatar_url) { nil }

    it 'creates a hidden field with value 1' do
      result = input.keep_field
      expect(result).to include('type="hidden"')
      expect(result).to include('value="1"')
      expect(result).to include('data-image-picker-target="keep"')
    end
  end

  describe '#preview' do
    context 'when has image' do
      let(:avatar_url) { 'https://example.com/avatar.jpg' }

      it 'shows preview with background image' do
        result = input.preview
        expect(result).to include("style='background-image: url(#{avatar_url})'")
        expect(result).not_to include('hidden')
      end
    end

    context 'when no image' do
      let(:avatar_url) { nil }

      it 'hides preview' do
        result = input.preview
        expect(result).to include('hidden')
      end
    end
  end

  describe '#has_image?' do
    context 'when avatar is present' do
      let(:avatar_url) { 'https://example.com/avatar.jpg' }

      it 'returns true' do
        expect(input.has_image?).to be true
      end
    end

    context 'when avatar is nil' do
      let(:avatar_url) { nil }

      it 'returns false' do
        expect(input.has_image?).to be false
      end
    end

    context 'when avatar is empty string' do
      let(:avatar_url) { '' }

      it 'returns false' do
        expect(input.has_image?).to be false
      end
    end
  end

  describe '#image_url' do
    let(:avatar_url) { 'https://example.com/avatar.jpg' }

    it 'returns the avatar URL from the object' do
      expect(input.image_url).to eq(avatar_url)
    end
  end

  describe '#remove' do
    context 'when has image' do
      let(:avatar_url) { 'https://example.com/avatar.jpg' }

      it 'shows remove button' do
        result = input.remove
        expect(result).not_to include('hidden')
        expect(result).to include('data-image-picker-target="remove"')
        expect(result).to include('data-action="click->image-picker#remove"')
      end
    end

    context 'when no image' do
      let(:avatar_url) { nil }

      it 'hides remove button' do
        result = input.remove
        expect(result).to include('hidden')
      end
    end
  end

  describe '#upload_button' do
    let(:avatar_url) { nil }

    it 'returns upload button HTML' do
      result = input.upload_button
      expect(result).to include('button-ghost')
      expect(result).to include('Parcourir vos fichiers')
    end
  end

  describe '#upload_svg' do
    let(:avatar_url) { nil }

    it 'returns SVG markup' do
      result = input.upload_svg
      expect(result).to include('<svg')
      expect(result).to include('width="90"')
      expect(result).to include('height="40"')
    end
  end

  describe '#br' do
    let(:avatar_url) { nil }

    it 'returns html safe br tag' do
      result = input.br
      expect(result).to eq('<br>'.html_safe)
      expect(result).to be_html_safe
    end
  end
end