class Skill::GenerateSemanticJob
  include Sidekiq::Job
  sidekiq_options queue: "default", retry: 3

  def perform(skill_id)
    skill = Skill.find(skill_id)

    url = URI("https://api.deepseek.com/chat/completions")
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request["Authorization"] = "Bearer #{ENV['DEEPSEEK_API_KEY']}"

    request.body = JSON.dump(
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            Tu es un expert en recrutement BTP et ingénierie. Pour la compétence donnée, fournis une liste de 3 à 8 termes synonymes ou associés permettant une recherche sémantique étendue.

            Règles :
            - Termes pertinents pour le matching candidat/projet
            - Pas de synonymes trop vagues ou trop éloignés
            - Variantes, formulations courantes, mots-clés associés

            Exemples :
            - "Gestion des équipes" → ["management", "encadrement", "supervision d'équipe", "leadership"]
            - "Photoshop" → ["retouche photo", "Adobe Photoshop", "logiciel de création graphique"]
            - "Excel" → ["tableur", "spreadsheet", "feuille de calcul"]

            Réponds uniquement en JSON : {"semantic": ["terme1", "terme2", ...]}
          PROMPT
        },
        {
          role: "user",
          content: skill.name
        }
      ],
      model: "deepseek-v4-flash",
      response_format: { type: "json_object" }
    )

    response = https.request(request)
    parsed = JSON.parse(response.body)
    content = parsed.dig("choices", 0, "message", "content")
    result = JSON.parse(content)

    semantic = result["semantic"]
    return unless semantic.is_a?(Array) && semantic.any?

    skill.update!(semantic: semantic)

    # Relancer l'embedding avec le nouveau semantic
    Skill::EmbedJob.perform_async(skill.id)
  end
end
