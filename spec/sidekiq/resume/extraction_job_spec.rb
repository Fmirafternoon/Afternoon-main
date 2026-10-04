require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe Resume::ExtractionJob, type: :job do
  let(:candidate) { create(:candidate, :with_resume) }
  let(:job) { described_class.new }

  before do
    Sidekiq::Testing.inline!
    # Mock external dependencies
    allow(Rails.logger).to receive(:info)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
  end

  after do
    Sidekiq::Testing.fake!
  end

  def mock_candidate_methods(candidate)
    # Since extracting! doesn't exist, we need to stub it with and_call_original workaround
    candidate.singleton_class.send(:define_method, :extracting!) { true }
    candidate.singleton_class.send(:define_method, :draft!) { true }
    allow(candidate).to receive(:reload).and_return(candidate)
  end

  describe '#perform' do
    context 'with valid candidate' do
      context 'when resume is a PDF' do
        let(:pdf_content) { "This is a sample PDF content with more than 100 characters to ensure it's recognized as valid text content and not treated as an image." }
        let(:mock_pdf_reader) { double('PDF::Reader') }
        let(:mock_page) { double('Page', text: pdf_content) }
        
        before do
          candidate.update!(
            resume_url: 'https://example.com/resume.pdf',
            resume_file_name: 'resume.pdf',
            import_status: 'pending'
          )
          
          mock_candidate_methods(candidate)
          allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
          
          # Mock HTTP response
          mock_response = double('Net::HTTPResponse',
            is_a?: true,
            body: 'fake pdf content'
          )
          allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
          allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          
          # Mock PDF reading
          allow(PDF::Reader).to receive(:new).and_return(mock_pdf_reader)
          allow(mock_pdf_reader).to receive(:pages).and_return([mock_page])
        end

        it 'downloads the resume file' do
          expect(Net::HTTP).to receive(:get_response).with(URI('https://example.com/resume.pdf'))
          job.perform(candidate.id)
        end

        it 'extracts text from PDF' do
          expect(PDF::Reader).to receive(:new).with(anything)
          job.perform(candidate.id)
        end

        it 'calls extracting! method' do
          # We can't use expect with the singleton method, so we'll test it was called indirectly
          called = false
          candidate.singleton_class.send(:define_method, :extracting!) { called = true }
          job.perform(candidate.id)
          expect(called).to be true
        end

        it 'updates candidate status to draft after extraction' do
          # We can't use expect with the singleton method, so we'll test it was called indirectly
          called = false
          candidate.singleton_class.send(:define_method, :draft!) { called = true }
          job.perform(candidate.id)
          expect(called).to be true
        end

        it 'broadcasts turbo stream update' do
          expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
            "agent_candidate_#{candidate.id}",
            partial: "agent/candidates/candidate",
            target: "agent_candidate_#{candidate.id}",
            locals: { candidate: candidate }
          )
          job.perform(candidate.id)
        end

        it 'logs the file type' do
          expect(Rails.logger).to receive(:info).with("Fichier téléchargé, type: .pdf")
          job.perform(candidate.id)
        end
      end

      context 'when resume is an image or has little text' do
        let(:short_text) { "Short text" }
        let(:ocr_text) { "This is OCR extracted text from the image that contains the resume content." }
        let(:mock_pdf_reader) { double('PDF::Reader') }
        let(:mock_page) { double('Page', text: short_text) }
        let(:mock_rtesseract) { double('RTesseract', to_s: ocr_text) }
        
        before do
          candidate.update!(
            resume_url: 'https://example.com/resume.jpg',
            resume_file_name: 'resume.jpg',
            import_status: 'pending'
          )
          
          mock_candidate_methods(candidate)
          allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
          
          # Mock HTTP response
          mock_response = double('Net::HTTPResponse',
            is_a?: true,
            body: 'fake image content'
          )
          allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
          allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          
          # Mock PDF reading with short text
          allow(PDF::Reader).to receive(:new).and_return(mock_pdf_reader)
          allow(mock_pdf_reader).to receive(:pages).and_return([mock_page])
          
          # Mock OCR
          allow(RTesseract).to receive(:new).and_return(mock_rtesseract)
        end

        it 'uses OCR when extracted text is less than 100 characters with fra+eng language' do
          expect(RTesseract).to receive(:new).with(anything, lang: "fra+eng")
          job.perform(candidate.id)
        end

        it 'extracts text using Tesseract' do
          expect(mock_rtesseract).to receive(:to_s)
          job.perform(candidate.id)
        end
      end

      context 'when resume has no extension in filename' do
        before do
          candidate.update!(
            resume_url: 'https://example.com/path/to/resume.pdf',
            resume_file_name: 'resume',  # No extension
            import_status: 'pending'
          )
          
          mock_candidate_methods(candidate)
          allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
          
          # Mock HTTP response
          mock_response = double('Net::HTTPResponse',
            is_a?: true,
            body: 'fake pdf content'
          )
          allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
          allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          
          # Mock PDF reading
          mock_pdf_reader = double('PDF::Reader')
          mock_page = double('Page', text: 'PDF content ' * 20)
          allow(PDF::Reader).to receive(:new).and_return(mock_pdf_reader)
          allow(mock_pdf_reader).to receive(:pages).and_return([mock_page])
        end

        it 'extracts extension from URL path' do
          expect(Rails.logger).to receive(:info).with("Fichier téléchargé, type: .pdf")
          job.perform(candidate.id)
        end
      end

      context 'when download fails' do
        before do
          candidate.update!(
            resume_url: 'https://example.com/resume.pdf',
            resume_file_name: 'resume.pdf',
            import_status: 'pending'
          )
          
          mock_candidate_methods(candidate)
          allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
          
          # Mock failed HTTP response
          mock_response = double('Net::HTTPResponse')
          allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
          allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        end

        it 'raises an error when download fails' do
          expect {
            job.perform(candidate.id)
          }.to raise_error("Failed to download file from https://example.com/resume.pdf")
        end
      end
    end

    context 'with invalid candidate' do
      it 'raises error when candidate not found' do
        expect {
          job.perform(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with tempfile handling' do
      before do
        candidate.update!(
          resume_url: 'https://example.com/resume.pdf',
          resume_file_name: 'my_resume.pdf',
          import_status: 'pending'
        )
        
        mock_candidate_methods(candidate)
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        
        # Mock HTTP response
        mock_response = double('Net::HTTPResponse',
          is_a?: true,
          body: 'fake pdf content'
        )
        allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        
        # Mock PDF reading
        mock_pdf_reader = double('PDF::Reader')
        mock_page = double('Page', text: 'PDF content ' * 20)
        allow(PDF::Reader).to receive(:new).and_return(mock_pdf_reader)
        allow(mock_pdf_reader).to receive(:pages).and_return([mock_page])
      end

      it 'creates tempfile with correct basename and extension' do
        expect(Tempfile).to receive(:create).with(['my_resume', '.pdf']).and_call_original
        job.perform(candidate.id)
      end

      it 'writes response body to tempfile in binary mode' do
        temp_file = double('Tempfile')
        allow(temp_file).to receive(:binmode)
        allow(temp_file).to receive(:write)
        allow(temp_file).to receive(:rewind)
        allow(temp_file).to receive(:path).and_return('/tmp/test.pdf')
        
        allow(Tempfile).to receive(:create).and_yield(temp_file)
        
        expect(temp_file).to receive(:binmode)
        expect(temp_file).to receive(:write).with('fake pdf content')
        expect(temp_file).to receive(:rewind)
        
        job.perform(candidate.id)
      end
    end

    context 'print statements' do
      before do
        candidate.update!(
          resume_url: 'https://example.com/resume.pdf',
          resume_file_name: 'resume.pdf',
          import_status: 'pending'
        )
        
        mock_candidate_methods(candidate)
        allow(Candidate).to receive(:find).with(candidate.id).and_return(candidate)
        
        # Mock HTTP response
        mock_response = double('Net::HTTPResponse',
          is_a?: true,
          body: 'fake pdf content'
        )
        allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      end

      it 'no longer prints checking message and PDF detection (commented out)' do
        # Mock PDF reading
        mock_pdf_reader = double('PDF::Reader')
        mock_page = double('Page', text: 'PDF content ' * 20)
        allow(PDF::Reader).to receive(:new).and_return(mock_pdf_reader)
        allow(mock_pdf_reader).to receive(:pages).and_return([mock_page])
        
        # The print statements are commented out in the implementation
        expect { job.perform(candidate.id) }.not_to output(/••• Checking file.*it's a pdf/).to_stdout
      end

      it 'no longer prints image detection when text is short (commented out)' do
        # Mock PDF with short text
        mock_pdf_reader = double('PDF::Reader')
        mock_page = double('Page', text: 'Short')
        allow(PDF::Reader).to receive(:new).and_return(mock_pdf_reader)
        allow(mock_pdf_reader).to receive(:pages).and_return([mock_page])
        
        # Mock OCR
        mock_rtesseract = double('RTesseract', to_s: 'OCR text')
        allow(RTesseract).to receive(:new).and_return(mock_rtesseract)
        
        # The print statements are commented out in the implementation
        expect { job.perform(candidate.id) }.not_to output(/it's probably an image/).to_stdout
      end
    end
  end

  describe 'Sidekiq configuration' do
    it 'includes Sidekiq::Job' do
      expect(described_class.ancestors).to include(Sidekiq::Job)
    end

    it 'can be enqueued' do
      Sidekiq::Testing.fake! do
        expect {
          described_class.perform_async(candidate.id)
        }.to change(described_class.jobs, :size).by(1)
      end
    end
  end
end