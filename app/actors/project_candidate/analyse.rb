class ProjectCandidate::Analyse < Actor
  input :project_candidate, type: ProjectCandidate

  output :json_output

  def call
    return nil if project_candidate.blank?

    url = URI("https://api.deepseek.com/chat/completions")

    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request["Authorization"] = "Bearer #{ENV['DEEPSEEK_API_KEY']}"

    request.body = JSON.dump(
      messages: [
        { "content": prompt, "role": "system" }
      ],
      model: "deepseek-v4-flash",
      stream: true,
      response_format: { type: "json_object" }
    )

    Rails.logger.info "ProjectCandidate #{project_candidate.id}: Sending analysis request to Deepseek API"
    start_time = Time.now

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

    elapsed_time = Time.now - start_time
    Rails.logger.info "ProjectCandidate #{project_candidate.id}: Analysis completed in #{elapsed_time.round(1)}s"

    begin
      self.json_output = JSON.parse(final_json_content)
    rescue JSON::ParserError => e
      Rails.logger.error "ProjectCandidate #{project_candidate.id}: Invalid JSON response: #{e}"
      raise "Invalid JSON response from Deepseek: #{e}"
    end
  end

  private

  def prompt
    @prompt ||= [
      prompt_template,
      schema
    ].join("\n\n")
  end

  def prompt_template
    template = File.read(Rails.root.join("config/prompts/project_candidate_analysis.md"))
    template
      .gsub("{{candidate_data}}", candidate_data.to_json)
      .gsub("{{project_data}}", project_data.to_json)
  end

  def schema
    [
      "# Schéma JSON à respecter",
      File.read(Rails.root.join("config/prompts/project_candidate_schema.json"))
    ].join("\n\n")
  end

  def candidate_data
    project_candidate.candidate.output
  end

  def project_data
    project_candidate.project.output
  end
end
