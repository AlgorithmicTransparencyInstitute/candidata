module Api
  class SocialMediaAccountsController < BaseController
    before_action :require_admin!, except: [:index, :show]
    before_action :set_account, only: [:show, :update, :destroy, :mark_entered, :mark_not_found, :verify, :reject]

    # GET /api/social_media_accounts?person_id=&platform=&research_status=&verified=&channel_type=&junkipedia=
    def index
      scope = SocialMediaAccount.order(id: :desc)
      scope = scope.where(person_id: params[:person_id]) if params[:person_id].present?
      scope = scope.by_platform(params[:platform]) if params[:platform].present?
      scope = scope.where(research_status: params[:research_status]) if params[:research_status].present?
      scope = scope.where(verified: params[:verified] == "true") if params[:verified].present?
      scope = scope.where(channel_type: params[:channel_type]) if params[:channel_type].present?
      case params[:junkipedia]
      when "pending"    then scope = scope.junkipedia_pending
      when "unresolved" then scope = scope.junkipedia_unresolved
      when "synced"     then scope = scope.junkipedia_synced
      when "errored"    then scope = scope.junkipedia_errored
      end

      records, meta = paginate(scope.includes(:person, :entered_by, :verified_by))
      json_response(records.map { |a| account_json(a) }, meta: meta)
    end

    def show
      json_response(account_detail_json(@account))
    end

    def create
      account = SocialMediaAccount.new(account_params)
      account.entered_by ||= current_user
      account.entered_at ||= Time.current
      account.research_status = "entered" if account.research_status.blank? || account.research_status == "not_started"
      account.save!
      json_response(account_detail_json(account), status: :created)
    end

    def update
      @account.update!(account_params)
      json_response(account_detail_json(@account))
    end

    def destroy
      @account.destroy!
      head :no_content
    end

    # POST /api/social_media_accounts/:id/mark_entered  { url:, handle: }
    def mark_entered
      @account.mark_entered!(current_user, url: params[:url], handle: params[:handle])
      json_response(account_detail_json(@account))
    end

    def mark_not_found
      @account.mark_not_found!(current_user)
      json_response(account_detail_json(@account))
    end

    # POST /api/social_media_accounts/:id/verify  { notes: }
    # Verifying triggers the Junkipedia auto-enqueue hook (by design).
    def verify
      @account.verify!(current_user, notes: params[:notes])
      json_response(account_detail_json(@account))
    end

    def reject
      @account.reject!(current_user, notes: params[:notes])
      json_response(account_detail_json(@account))
    end

    private

    def set_account
      @account = SocialMediaAccount.find(params[:id])
    end

    def account_params
      params.require(:social_media_account).permit(
        :person_id, :platform, :channel_type, :url, :handle, :account_inactive
      )
    end

    def account_json(account)
      {
        id: account.id,
        person_id: account.person_id,
        person_name: account.person.full_name,
        platform: account.platform,
        handle: account.handle,
        url: account.url,
        channel_type: account.channel_type,
        research_status: account.research_status,
        verified: account.verified,
        account_inactive: account.account_inactive,
        junkipedia_sync_status: account.junkipedia_sync_status
      }
    end

    def account_detail_json(account)
      account_json(account).merge(
        pre_populated: account.pre_populated,
        entered_by: user_ref(account.entered_by),
        entered_at: account.entered_at,
        verified_by: user_ref(account.verified_by),
        verified_at: account.verified_at,
        verification_notes: account.verification_notes,
        research_notes: account.research_notes,
        needs_secondary_verification: account.needs_secondary_verification,
        modified_during_validation: account.modified_during_validation,
        previous_url: account.previous_url,
        version_count: account.version_count,
        junkipedia_channel_id: account.junkipedia_channel_id,
        junkipedia_enqueued_at: account.junkipedia_enqueued_at,
        junkipedia_id_collected_at: account.junkipedia_id_collected_at,
        junkipedia_last_error: account.junkipedia_last_error
      )
    end

    def user_ref(user)
      return nil unless user

      { id: user.id, email: user.email, name: user.name }
    end
  end
end
