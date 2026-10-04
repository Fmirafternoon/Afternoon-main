class Resume::EmbedJob
  include Sidekiq::Job

  def perform(candidate_id)
    @candidate = Candidate.find(candidate_id)

    result = Embedding::Create.call(text: [
      @candidate.position,
      @candidate.position,
      *resume_summary_as_sentences
    ])

    raise "Embedding vide retourné pour Candidate##{candidate_id}" if result.embedding.blank?

    @candidate.update(job_title_embedding: result.embedding)
  end

  private

  def resume_summary_as_sentences
    return [] if @candidate.resume_summary.blank?

    @candidate.resume_summary.map do |key, value|
      label = key.humanize

      next if value.blank?

      content = value.is_a?(Array) ? value.join(", ") : value
      "#{label} : #{content}"
    end.compact
  end
end
