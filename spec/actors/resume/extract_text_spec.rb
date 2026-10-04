require 'rails_helper'

RSpec.describe Resume::ExtractText do
  let(:document) do
    double("Document",
      file_name: "resume.pdf",
      url: "https://example.com/resume.pdf"
    )
  end
  let(:actor_result) { described_class.call(document: document) }

  before do
    # Suppress Rails logger output in tests
    allow(Rails.logger).to receive(:info)
    
    # Mock MiniMagick and RTesseract globally to prevent ImageMagick calls
    allow(MiniMagick).to receive(:convert)
    allow(RTesseract).to receive(:new).and_return(double(to_s: "OCR text"))
  end

  describe '#call' do
    context 'when downloading a PDF with text content' do
      let(:pdf_content) { "Fake PDF content" }
      let(:extracted_text) { "John Doe\nSoftware Engineer\n\nExperience: 5 years in Ruby on Rails with extensive experience in building scalable web applications and RESTful APIs" }
      
      before do
        # Mock HTTP response
        response = double("HTTPResponse", 
          is_a?: true, 
          body: pdf_content
        )
        allow(Net::HTTP).to receive(:get_response).and_return(response)
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        
        # Mock Tempfile
        temp_file = double("Tempfile",
          binmode: nil,
          write: nil,
          rewind: nil,
          read: "%PDF",
          path: "/tmp/test.pdf"
        )
        allow(Tempfile).to receive(:create).and_yield(temp_file)

        # Mock PDF::Reader
        pdf_reader = double("PDF::Reader")
        allow(PDF::Reader).to receive(:new).with("/tmp/test.pdf").and_return(pdf_reader)

        page1 = double("Page", text: "John Doe\nSoftware Engineer\n")
        page2 = double("Page", text: "Experience: 5 years in Ruby on Rails with extensive experience in building scalable web applications and RESTful APIs")
        allow(pdf_reader).to receive(:pages).and_return([page1, page2])
      end

      it 'returns success' do
        expect(actor_result).to be_success
      end

      it 'extracts text from PDF' do
        expect(actor_result.extracted_text).to eq(extracted_text)
      end

      it 'downloads the file from the URL' do
        expect(Net::HTTP).to receive(:get_response).with(URI("https://example.com/resume.pdf"))
        actor_result
      end
    end

    context 'when downloading fails' do
      before do
        response = double("HTTPResponse")
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(Net::HTTP).to receive(:get_response).and_return(response)
      end

      it 'raises an error' do
        expect { actor_result }.to raise_error(RuntimeError, /Failed to download file/)
      end
    end

    context 'when PDF has minimal text (requires OCR)' do
      let(:pdf_content) { "Fake PDF content" }
      let(:short_text) { "Short" }
      let(:ocr_text) { "OCR extracted text from image" }
      
      before do
        # Mock HTTP response
        response = double("HTTPResponse", 
          is_a?: true, 
          body: pdf_content
        )
        allow(Net::HTTP).to receive(:get_response).and_return(response)
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        
        # Mock Tempfile
        temp_file = double("Tempfile",
          binmode: nil,
          write: nil,
          rewind: nil,
          read: "%PDF",
          path: "/tmp/test.pdf"
        )
        image_file = double("ImageFile", path: "/tmp/image.png")
        allow(Tempfile).to receive(:create).with(["resume", ".pdf"]).and_yield(temp_file)
        allow(Tempfile).to receive(:create).with(["converted", ".png"]).and_yield(image_file)
        
        # Mock PDF::Reader with short text
        pdf_reader = double("PDF::Reader")
        allow(PDF::Reader).to receive(:new).with("/tmp/test.pdf").and_return(pdf_reader)
        page = double("Page", text: short_text)
        allow(pdf_reader).to receive(:pages).and_return([page])
        
        # Mock MiniMagick
        convert_double = double("convert")
        allow(convert_double).to receive(:density).with(300)
        allow(convert_double).to receive(:quality).with(100)
        allow(convert_double).to receive(:<<).with(anything)
        allow(MiniMagick).to receive(:convert).and_yield(convert_double)
        
        # Mock RTesseract
        rtesseract = double("RTesseract", to_s: ocr_text)
        allow(RTesseract).to receive(:new).with("/tmp/image.png", lang: "fra+eng").and_return(rtesseract)
      end

      it 'performs OCR when text is too short' do
        expect(actor_result.extracted_text).to eq(ocr_text)
      end

      it 'converts PDF to image before OCR' do
        expect(MiniMagick).to receive(:convert)
        actor_result
      end

      it 'uses RTesseract for OCR with fra+eng language' do
        expect(RTesseract).to receive(:new).with("/tmp/image.png", lang: "fra+eng").and_return(double(to_s: ocr_text))
        actor_result
      end
    end

    context 'with different file extensions' do
      context 'when file has no extension in filename' do
        let(:document) do
          double("Document",
            file_name: "resume",
            url: "https://example.com/files/document.pdf"
          )
        end

        before do
          # Mock HTTP response
          response = double("HTTPResponse", 
            is_a?: true, 
            body: "PDF content"
          )
          allow(Net::HTTP).to receive(:get_response).and_return(response)
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          
          # Mock Tempfile
          temp_file = double("Tempfile",
            binmode: nil,
            write: nil,
            rewind: nil,
            read: "%PDF",
            path: "/tmp/test.pdf"
          )
          allow(Tempfile).to receive(:create).and_yield(temp_file)

          # Mock PDF::Reader
          pdf_reader = double("PDF::Reader")
          allow(PDF::Reader).to receive(:new).with("/tmp/test.pdf").and_return(pdf_reader)
          page = double("Page", text: "Resume text content with more than 100 characters to avoid OCR processing. This is additional text to ensure we have enough characters to bypass the OCR threshold.")
          allow(pdf_reader).to receive(:pages).and_return([page])
        end

        it 'extracts extension from URL' do
          expect(actor_result).to be_success
          expect(actor_result.extracted_text).to include("Resume text content")
        end
      end

      context 'when file is not a PDF' do
        let(:document) do
          double("Document",
            file_name: "document.txt",
            url: "https://example.com/document.txt"
          )
        end

        before do
          # Mock HTTP response
          response = double("HTTPResponse", 
            is_a?: true, 
            body: "Plain text content"
          )
          allow(Net::HTTP).to receive(:get_response).and_return(response)
          allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
          
          # Mock Tempfile
          temp_file = double("Tempfile",
            binmode: nil,
            write: nil,
            rewind: nil,
            read: "NOT_",
            path: "/tmp/test.txt"
          )
          allow(Tempfile).to receive(:create).and_yield(temp_file)
        end

        it 'returns empty string for non-PDF files' do
          expect(actor_result.extracted_text).to eq("")
        end
      end
    end

    context 'with PDF containing exactly 100 characters' do
      let(:pdf_content) { "Fake PDF content" }
      let(:text_100_chars) { "a" * 100 }
      
      before do
        # Mock HTTP response
        response = double("HTTPResponse", 
          is_a?: true, 
          body: pdf_content
        )
        allow(Net::HTTP).to receive(:get_response).and_return(response)
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        
        # Mock Tempfile
        temp_file = double("Tempfile",
          binmode: nil,
          write: nil,
          rewind: nil,
          read: "%PDF",
          path: "/tmp/test.pdf"
        )
        allow(Tempfile).to receive(:create).and_yield(temp_file)

        # Mock PDF::Reader
        pdf_reader = double("PDF::Reader")
        allow(PDF::Reader).to receive(:new).with("/tmp/test.pdf").and_return(pdf_reader)
        page = double("Page", text: text_100_chars)
        allow(pdf_reader).to receive(:pages).and_return([page])
      end

      it 'does not perform OCR when text has exactly 100 characters' do
        expect(MiniMagick).not_to receive(:convert)
        expect(RTesseract).not_to receive(:new)
        expect(actor_result.extracted_text).to eq(text_100_chars)
      end
    end

    context 'with case-insensitive file extension' do
      let(:document) do
        double("Document",
          file_name: "RESUME.PDF",
          url: "https://example.com/RESUME.PDF"
        )
      end

      before do
        # Mock HTTP response
        response = double("HTTPResponse", 
          is_a?: true, 
          body: "PDF content"
        )
        allow(Net::HTTP).to receive(:get_response).and_return(response)
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        
        # Mock Tempfile
        temp_file = double("Tempfile",
          binmode: nil,
          write: nil,
          rewind: nil,
          read: "%PDF",
          path: "/tmp/test.PDF"
        )
        allow(Tempfile).to receive(:create).and_yield(temp_file)
        
        # Mock PDF::Reader
        pdf_reader = double("PDF::Reader")
        allow(PDF::Reader).to receive(:new).with("/tmp/test.PDF").and_return(pdf_reader)
        page = double("Page", text: "Content from uppercase PDF extension")
        allow(pdf_reader).to receive(:pages).and_return([page])
      end

      it 'handles uppercase file extensions' do
        expect(PDF::Reader).to receive(:new)
        actor_result
      end
    end
  end
end