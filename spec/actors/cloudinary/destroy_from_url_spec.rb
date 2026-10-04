require 'rails_helper'

RSpec.describe Cloudinary::DestroyFromUrl do
  let(:url) { "https://res.cloudinary.com/demo/image/upload/v1234567890/sample.jpg" }
  let(:actor_result) { described_class.call(url: url) }

  describe '#call' do
    context 'when successful' do
      before do
        allow(Cloudinary::Uploader).to receive(:destroy).and_return(true)
      end

      it 'returns success' do
        expect(actor_result).to be_success
      end

      it 'calls Cloudinary::Uploader.destroy with the correct public_id' do
        expect(Cloudinary::Uploader).to receive(:destroy).with("sample", type: :upload)
        actor_result
      end
    end

    context 'with different Cloudinary URL formats' do
      [
        {
          url: "https://res.cloudinary.com/demo/image/upload/v1234567890/sample.jpg",
          expected_id: "sample"
        },
        {
          url: "https://res.cloudinary.com/demo/image/upload/sample.jpg",
          expected_id: "sample"
        },
        {
          url: "https://res.cloudinary.com/demo/image/upload/v1234567890/folder/sample.jpg",
          expected_id: "folder/sample"
        },
        {
          url: "https://res.cloudinary.com/demo/video/upload/v1234567890/my-video.mp4",
          expected_id: "my-video"
        },
        {
          url: "https://res.cloudinary.com/demo/raw/upload/v1234567890/document.pdf",
          expected_id: "document"
        },
        {
          url: "https://res.cloudinary.com/demo/image/fetch/v1234567890/sample.jpg",
          expected_id: "sample"
        },
        {
          url: "https://res.cloudinary.com/demo/image/private/v1234567890/sample.jpg",
          expected_id: "sample"
        },
        {
          url: "https://res.cloudinary.com/demo/image/authenticated/v1234567890/sample.jpg",
          expected_id: "sample"
        }
      ].each do |test_case|
        it "extracts public_id '#{test_case[:expected_id]}' from #{test_case[:url]}" do
          allow(Cloudinary::Uploader).to receive(:destroy)
          
          described_class.call(url: test_case[:url])
          
          expect(Cloudinary::Uploader).to have_received(:destroy).with(test_case[:expected_id], type: :upload)
        end
      end
    end

    context 'with nil or empty URL' do
      it 'handles nil URL' do
        allow(Cloudinary::Uploader).to receive(:destroy)
        
        described_class.call(url: nil)
        
        expect(Cloudinary::Uploader).to have_received(:destroy).with("", type: :upload)
      end

      it 'handles empty URL' do
        allow(Cloudinary::Uploader).to receive(:destroy)
        
        described_class.call(url: "")
        
        expect(Cloudinary::Uploader).to have_received(:destroy).with("", type: :upload)
      end
    end

    context 'with non-Cloudinary URL' do
      let(:url) { "https://example.com/image.jpg" }

      it 'passes the full URL as public_id' do
        allow(Cloudinary::Uploader).to receive(:destroy)
        
        actor_result
        
        expect(Cloudinary::Uploader).to have_received(:destroy).with(url, type: :upload)
      end
    end

    context 'when Cloudinary::Uploader raises an error' do
      before do
        allow(Cloudinary::Uploader).to receive(:destroy).and_raise(CloudinaryException.new("API error"))
      end

      it 'lets the error bubble up' do
        expect { actor_result }.to raise_error(CloudinaryException, "API error")
      end
    end
  end

  describe 'regex pattern' do
    it 'has CLOUDINARY_REGEX constant defined' do
      expect(described_class::CLOUDINARY_REGEX).to be_a(Regexp)
    end

    it 'matches standard Cloudinary URLs' do
      url = "https://res.cloudinary.com/demo/image/upload/v1234567890/sample.jpg"
      expect(url).to match(described_class::CLOUDINARY_REGEX)
    end
  end
end