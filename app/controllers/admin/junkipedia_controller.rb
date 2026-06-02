module Admin
  class JunkipediaController < BaseController
    before_action :set_account, only: [:enqueue, :resolve]

    FILTERS = %w[all pending enqueued synced errored].freeze

    def index
      @filter = FILTERS.include?(params[:filter]) ? params[:filter] : 'pending'

      base = SocialMediaAccount.includes(:person)
      @scope = case @filter
               when 'pending'  then base.junkipedia_pending
               when 'enqueued' then base.junkipedia_unresolved
               when 'synced'   then base.junkipedia_synced
               when 'errored'  then base.junkipedia_errored
               else                 base.junkipedia_eligible
               end

      @scope = @scope.where(platform: params[:platform]) if params[:platform].present?
      @scope = @scope.joins(:person).where(people: { state_of_residence: params[:state] }) if params[:state].present?

      @counts = {
        pending:   SocialMediaAccount.junkipedia_pending.count,
        enqueued:  SocialMediaAccount.junkipedia_unresolved.count,
        synced:    SocialMediaAccount.junkipedia_synced.count,
        errored:   SocialMediaAccount.junkipedia_errored.count,
        eligible:  SocialMediaAccount.junkipedia_eligible.count
      }

      @accounts = @scope.order(updated_at: :desc).page(params[:page]).per(50)
      @platforms = JunkipediaService::SUPPORTED_PLATFORMS
      @api_token_configured = ENV['JUNKIPEDIA_API_TOKEN'].present?
      @default_list_id = ENV['JUNKIPEDIA_DEFAULT_LIST_ID']
    end

    def enqueue
      EnqueueJunkipediaChannelJob.perform_later(@account.id, force: true)
      redirect_back fallback_location: admin_junkipedia_path,
                    notice: "Re-enqueue scheduled for #{@account.display_name}."
    end

    def resolve
      ResolveJunkipediaChannelIdJob.perform_later(@account.id, force: true)
      redirect_back fallback_location: admin_junkipedia_path,
                    notice: "Channel ID resolution scheduled for #{@account.display_name}."
    end

    def enqueue_all
      ids = SocialMediaAccount.junkipedia_pending.pluck(:id)
      ids.each { |id| EnqueueJunkipediaChannelJob.perform_later(id) }
      redirect_to admin_junkipedia_path(filter: 'pending'),
                  notice: "Enqueued #{ids.size} verified accounts to Junkipedia."
    end

    def resolve_all
      ids = SocialMediaAccount.junkipedia_unresolved.pluck(:id)
      ids.each { |id| ResolveJunkipediaChannelIdJob.perform_later(id) }
      redirect_to admin_junkipedia_path(filter: 'enqueued'),
                  notice: "Scheduled channel ID resolution for #{ids.size} accounts."
    end

    # Search Junkipedia for matches across all pending (un-enqueued) accounts.
    # Records previously pushed via the rake tasks are already in Junkipedia, so
    # search will find them instantly — they get marked synced without the
    # slower POST /channels round trip. The unmatched remainder stays pending
    # for the regular enqueue path.
    def preflight_resolve_all
      ids = SocialMediaAccount.junkipedia_pending.pluck(:id)
      ids.each { |id| ResolveJunkipediaChannelIdJob.perform_later(id) }
      redirect_to admin_junkipedia_path(filter: 'pending'),
                  notice: "Scheduled Junkipedia channel search for #{ids.size} pending accounts. Matched accounts will move to Synced; the rest stay Pending."
    end

    private

    def set_account
      @account = SocialMediaAccount.find(params[:id])
    end
  end
end
