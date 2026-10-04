class Resume::PublicationCheck < Actor
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

    puts "Sending Publication Check streaming request to Deepseek API..."
    start_time = Time.now

    # Utilisation du bloc pour lire le streaming en temps réel
    final_json_content = ""
    line_buffer = ""
    done = false

    https.request(request) do |response|
      response.read_body do |chunk|
        next if done
        line_buffer << chunk

        # On ne traite une ligne QUE lorsqu'elle est complète (terminée par un \n).
        # Le morceau incomplet reste dans line_buffer en attendant le chunk suivant.
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
            if parsed.dig("choices", 0, "delta", "content")
              final_json_content << parsed["choices"][0]["delta"]["content"]
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
      publication_check_prompt,
      resume_from_database
    ].join("\n\n")
  end

  def publication_check_prompt
    [
      "[DATE_ACTUELLE] = #{I18n.l(Date.today)}",
      File.read(Rails.root.join("config/prompts/publication_check_resume.md"))
    ].join("\n\n")
  end

  def resume_from_database
    [
      "# Informations de la candidature",
      "Voici les informations de la candidature présentes en base de données",
      candidate.output
    ].join("\n\n")
  end
end
