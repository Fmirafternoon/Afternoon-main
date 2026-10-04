class Resume::UpsertBatch < Actor
  input :candidate
  input :user

  def call
    candidate.import_pending!
    active_batch_key = "agent:#{user.id}:active_import_batch"
    batch_candidates_key = "agent:#{user.id}:active_candidates_import"

    active_bid = REDIS.get(active_batch_key)

    if active_bid.present?
      batch = Sidekiq::Batch.new(active_bid)
      batch.jobs do
        Resume::AnalyseLlmJob.perform_async(candidate.id)
      end
    else
      batch = Sidekiq::Batch.new
      batch.description = "Import batch for user #{user.id}"
      batch.on(:success, Resume::BatchImportCallback, { user_id: user.id })
      batch.jobs do
        Resume::AnalyseLlmJob.perform_async(candidate.id)
      end
      REDIS.setex(active_batch_key, 10.minutes.to_i, batch.bid)
    end

    REDIS.rpush(batch_candidates_key, candidate.id)
  end
end
