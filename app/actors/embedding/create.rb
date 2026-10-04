class Embedding::Create < Actor
  input :text, type: Array, default: -> { [] }

  output :embedding, type: Array, default: -> { [] }

  def call
    payload = {
      model: ENV.fetch("EMBEDDING_MODEL_ID"),
      input: text,
      input_type: "search_document",
      encoding_format: "raw"
    }

    uri = URI.join(ENV.fetch("EMBEDDING_URL"), "/v1/embeddings")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV.fetch("EMBEDDING_KEY")}"
    request["Content-Type"]  = "application/json"
    request.body             = payload.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end
    self.embedding = parse_embedding_output(response)
  end

  private

  def parse_embedding_output(response)
    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      result["data"][0]["embedding"]
    else
      puts "Request failed: #{response.code}, #{response.body}"
      []
    end
  rescue => e
    []
  end
end
