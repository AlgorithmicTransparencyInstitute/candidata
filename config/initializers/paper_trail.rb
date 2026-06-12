# Default PaperTrail attribution for non-request contexts.
#
# - Web requests:    ApplicationController's set_paper_trail_whodunnit
#                    (versions.whodunnit = current_user.id)
# - Background jobs: ApplicationJob around_perform ("job:ClassName")
# - Everything else: labeled here so rake imports, runner scripts, and console
#   sessions are distinguishable from user edits in version history.
#
# Sets the boot thread only. Server request threads start nil and get the
# per-request value from the controller callback, so the generic "cli:" label
# never leaks onto user-driven changes.
Rails.application.config.after_initialize do
  rake_tasks =
    if defined?(Rake) && Rake.respond_to?(:application)
      Rake.application.top_level_tasks.reject { |t| t == "default" }
    else
      []
    end

  PaperTrail.request.whodunnit =
    if defined?(Rails::Console)
      "console:#{ENV['USER']}"
    elsif rake_tasks.any?
      "rake:#{rake_tasks.join(',')}"
    else
      "cli:#{File.basename($PROGRAM_NAME)}"
    end
end
