module Api
  class SocialMediaAccountsController < BaseController
    before_action :find_account, only: [:show, :update, :mark_entered, :mark_not_found, :verify, :reject]
    before_action :authorize_admin!, except: [:show]

    def index
      scope = SocialMediaAccount.all
      scope = scope.where(person_id: params[:person_id]) if params[:person_id].present?
      scope = scope.by_platform(params[:platform]) if params[:platform].present?
      scope = scope.where(research_status: params[:research_status]) if params[:research_status].present?
      scope = scope.where(verified: params[:verified] == 'true') if params[:verified].present?
      scope = scope.where(channel_type: params[:channel_type]) if params[:channel_type].present?

      records, meta = paginate(scope.includes(:person, :entered_by, :verified_by), page: params[:page], per_page: params[:per_page])
      json_response(records.map { |a| account_json(a) }, meta: meta)
    end

    def show
      json_response(account_detail_json(@account))
    end

    def create
      account = SocialMediaAccount.new(account_params)
      account.save!
      json_response(account_detail_json(account), status: :created)
    end

    def update
      @account.update!(account_params)
      json_response(account_detail_json(@account))
    end

    def mark_entered
      @account.mark_entered!(
        current_user,
        url: params[:url],
        handle: params[:handle]
      )
      json_response(account_detail_json(@account))
    end

    def mark_not_found
      @account.mark_not_found!(current_user)
      json_response(account_detail_json(@account))
    end

    def verify
      @account.verify!(current_user, notes: params[:notes])
      json_response(account_detail_json(@account))
    end

    def reject
      @account.reject!(current_user, notes: params[:notes])
      json_response(account_detail_json(@account))
    end

    private

    def find_account
      @account = SocialMediaAccount.find(params[:id])
    end

    def authorize_admin!
      render json: { error: "Unauthorized", code: "FORBIDDEN" }, status: :forbidden unless current_user.admin?
    end

    def account_params
      params.require(:social_media_account).permit(
        :person_id, :platform, :handle, :url, :channel_type, :account_inactive, :pre_populated
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
        pre_populated: account.pre_populated,
        entered_by: account.entered_by&.email,
        entered_at: account.entered_at,
        verified_by: account.verified_by&.email,
        verified_at: account.verified_at,
        version_count: account.version_count
      }
    end

    def account_detail_json(account)
      {
        id: account.id,
        person_id: account.person_id,
        person: {
          id: account.person.id,
          first_name: account.person.first_name,
          last_name: account.person.last_name,
          full_name: account.person.full_name,
          state_of_residence: account.person.state_of_residence
        },
        platform: account.platform,
        handle: account.handle,
        url: account.url,
        channel_type: account.channel_type,
        account_inactive: account.account_inactive,
        pre_populated: account.pre_populated,
        research_status: account.research_status,
        verified: account.verified,
        entered_by: account.entered_by ? { id: account.entered_by.id, email: account.entered_by.email } : nil,
        entered_at: account.entered_at,
        verified_by: account.verified_by ? { id: account.verified_by.id, email: account.verified_by.email } : nil,
        verified_at: account.verified_at,
        verification_notes: account.verification_notes,
        previous_url: account.previous_url,
        needs_secondary_verification: account.needs_secondary_verification,
        version_count: account.version_count,
        junkipedia_channel_id: account.junkipedia_channel_id,
        junkipedia_sync_status: account.junkipedia_sync_status,
        junkipedia_enqueued_at: account.junkipedia_enqueued_at,
        junkipedia_last_error: account.junkipedia_last_error
      }
    end
  end
end
