class Resume::BatchImportCallback
  def on_success(status, options)
    user = User.find(options["user_id"])

    active_batch_key = "agent:#{user.id}:active_import_batch"
    batch_candidates_key = "agent:#{user.id}:active_candidates_import"

    candidate_ids = REDIS.lrange(batch_candidates_key, 0, -1)

    AgentMailer.import_complete(user.id, candidate_ids).deliver_later
    Rails.logger.info "Import batch terminé pour l'utilisateur #{user.id}"

    REDIS.del(batch_candidates_key)
    REDIS.del(active_batch_key)
  end
end
