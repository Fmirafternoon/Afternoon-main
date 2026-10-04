require "net/http"
require "uri"

class Resume::ExtractionJob
  include Sidekiq::Job

  def perform(candidate_id)
    candidate = Candidate.find(candidate_id)
    candidate.extracting!

    extracted_text = ""

    Tempfile.create([File.basename(candidate.resume_file_name, ".*"), File.extname(candidate.resume_file_name)]) do |temp_file|
      temp_file.binmode

      uri = URI(candidate.resume_url)
      response = Net::HTTP.get_response(uri)
      unless response.is_a?(Net::HTTPSuccess)
        raise "Failed to download file from #{candidate.resume_url}"
      end
      temp_file.write(response.body)
      temp_file.rewind

      extension = File.extname(candidate.resume_file_name)
      if extension.empty?
        extension = File.extname(URI.parse(candidate.resume_url).path)
      end

      Rails.logger.info "Fichier téléchargé, type: #{extension}"

      # print "••• Checking file #{temp_file.path}... "
      if extension.end_with?(".pdf")
        # puts "it's a pdf"
        reader = PDF::Reader.new(temp_file.path)
        extracted_text = reader.pages.map(&:text).join("\n")
      end

      if extracted_text.length < 100
        # puts "it's probably an image"
        # Extraction OCR avec Tesseract
        image = RTesseract.new(temp_file.path, lang: "fra+eng")
        extracted_text = image.to_s
      end
    end

    candidate.draft!
    candidate.reload

    Turbo::StreamsChannel.broadcast_replace_to(
      ActionView::RecordIdentifier.dom_id(candidate, :agent),
      partial: "agent/candidates/candidate",
      target: ActionView::RecordIdentifier.dom_id(candidate, :agent),
      locals: { candidate: candidate }
    )
  end
end
