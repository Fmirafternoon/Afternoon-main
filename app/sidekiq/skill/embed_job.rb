class Skill::EmbedJob
  include Sidekiq::Job

  def perform(skill_id)
    @skill = Skill.find(skill_id)

    result = Embedding::Create.call(text: [
      @skill.name,
      @skill.semantic.join(", ")
    ])

    raise "Embedding vide retourné pour Skill##{skill_id}" if result.embedding.blank?

    @skill.update!(embedding: result.embedding)
  end
end
