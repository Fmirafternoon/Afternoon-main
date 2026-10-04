class Resume::Analyse < Actor
  input :candidate, default: nil

  output :json_output

  def call
    return nil if candidate.blank?

    url = URI("https://api.deepseek.com/chat/completions")

    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request["Authorization"] = "Bearer #{ENV['DEEPSEEK_API_KEY']}"

    p prompt

    request.body = JSON.dump(
      messages: [
        { "content": prompt, "role": "system" }
      ],
      model: "deepseek-v4-flash",
      stream: true,
      response_format: { type: "json_object" }
    )

    puts "Sending Analyse streaming request to Deepseek API..."
    start_time = Time.now

    final_json_content = ""
    line_buffer = ""
    done = false

    https.request(request) do |response|
      response.read_body do |chunk|
        next if done
        line_buffer += chunk
        while (newline_idx = line_buffer.index("\n"))
          line = line_buffer[0, newline_idx].strip
          line_buffer = line_buffer[(newline_idx + 1)..]
          next if line.empty? || line.start_with?(":")
          next unless line.start_with?("data:")

          data_line = line.sub("data: ", "").strip
          if data_line == "[DONE]"
            done = true
            break
          end

          begin
            parsed = JSON.parse(data_line)
            if parsed["choices"] && parsed["choices"][0] && parsed["choices"][0]["delta"]
              delta = parsed["choices"][0]["delta"]
              final_json_content << delta["content"] if delta["content"]
            end
          rescue JSON::ParserError => e
            raise "Erreur de parsing JSON: #{e}"
          end
        end
      end
    end
    p final_json_content
    end_time = Time.now
    elapsed_time = end_time - start_time
    minutes = (elapsed_time / 60).to_i
    seconds = (elapsed_time % 60).to_i
    puts "\nElapsed time: #{format('%02d:%02d', minutes, seconds)}"
    puts "=" * 50

    begin
      json_parsed = JSON.parse(final_json_content)
      puts "\nJSON reconstitué correctement."
      self.json_output = json_parsed
    rescue JSON::ParserError => e
      puts "\nLe JSON final n'est pas valide: #{e}"
    end
  end

  private

  def prompt
    @prompt ||= [
      analyze_resume_prompt,
      resume_from_database,
      extracted_text_from_pdf_resume,
      documents_from_database,
      schema
    ].join("\n\n")
  end

  def analyze_resume_prompt
    [
      "[DATE_ACTUELLE] = #{I18n.l(Date.today)}",
      File.read(Rails.root.join("config/prompts/analyze_resume.md")),
      "[Secteurs d'activités] = #{Sector.all.as_json(only: [:id, :name])}"
    ].join("\n\n")
  end

  def schema
    [
      "# Schéma JSON à respecter",
      "Voici le schéma json à respecter",
      "Attention à ne pas inclure les données personnelles : nom, prénom, adresse complète, numéro de téléphone et email des champs qui ne doivent pas en contenir",
      File.read(Rails.root.join("config/prompts/resume_schema.json"))
    ].join("\n\n")
  end

  def resume_from_database
    [
      "# Informations de la candidature",
      "Voici les informations de la candidature présentes en base de données",
      "Supprimer les données personnelles : nom, prénom, adresse complète, numéro de téléphone et email des champs qui ne doivent pas en contenir",
      candidate.output
    ].join("\n\n")
  end

  def extracted_text_from_pdf_resume
    extracted_text = Resume::ExtractText.call(document: OpenStruct.new(file_name: candidate.resume_file_name, url: candidate.resume_url)).extracted_text

    [
      "# Contenu du CV à analyser",
      "Voici le contenu du CV en PDF à analyser",
      extracted_text
    ].join("\n\n")
  end

  def documents_from_database
    return nil if candidate.blank?

    text = candidate.candidate_documents.map do |document|
      [
        "-------#{document.file_name}-------",
        Resume::ExtractText.call(document: document).extracted_text
      ].join("\n")
    end

    [
      "# Documents relatifs à ce candidat",
      "Voici autres les documents relatifs à ce candidat",
      text.join("\n\n")
    ].join("\n\n")
  end
end
