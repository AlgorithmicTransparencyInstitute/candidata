class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # PaperTrail: label changes made by background jobs (e.g. "job:EnqueueJunkipediaChannelJob")
  # so version history distinguishes them from user edits.
  around_perform do |job, block|
    PaperTrail.request(whodunnit: "job:#{job.class.name}") { block.call }
  end
end
