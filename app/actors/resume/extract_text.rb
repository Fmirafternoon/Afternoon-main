class Resume::ExtractText < Actor
  input :document

  output :extracted_text, default: -> { "" }

  def call
    Tempfile.create(["resume", File.extname(document.file_name.to_s)]) do |temp_file|
      temp_file.binmode

      # Téléchargement du fichier
      uri = URI(document.url)
      response = Net::HTTP.get_response(uri)
      unless response.is_a?(Net::HTTPSuccess)
        raise "Failed to download file from #{document.url}"
      end
      temp_file.write(response.body)
      temp_file.rewind

      extension = detect_extension(temp_file, document)

      Rails.logger.info "Fichier téléchargé, type: #{extension}"

      # Si PDF, extraire le texte
      if extension == ".pdf"
        reader = PDF::Reader.new(temp_file.path)
        self.extracted_text = reader.pages.map(&:text).join("\n")
      end

      # Si texte trop court, probablement une image PDF : OCR requis
      if extracted_text.length < 100 && extension == ".pdf"
        Rails.logger.info "PDF sans texte, tentative d'OCR"

        # Convertir le PDF en image (première page seulement)
        Tempfile.create(["converted", ".png"]) do |image_file|
          MiniMagick.convert do |convert|
            convert.density(300)
            convert.quality(100)
            convert << "#{temp_file.path}[0]"
            convert << image_file.path
          end

          # OCR avec RTesseract sur l'image convertie
          image = RTesseract.new(image_file.path, lang: "fra+eng")
          self.extracted_text = image.to_s
        end
      end
    end
  end

  private

  def detect_extension(temp_file, document)
    # Détecter par magic bytes (le plus fiable)
    temp_file.rewind
    header = temp_file.read(4).to_s
    temp_file.rewind

    return ".pdf" if header.start_with?("%PDF")

    # Fallback sur le file_name
    ext = File.extname(document.file_name.to_s).downcase
    return ext if [".pdf", ".doc", ".docx", ".png", ".jpg", ".jpeg"].include?(ext)

    # Fallback sur l'URL
    ext = File.extname(URI.parse(document.url).path).downcase
    return ext if [".pdf", ".doc", ".docx", ".png", ".jpg", ".jpeg"].include?(ext)

    ""
  end
end
