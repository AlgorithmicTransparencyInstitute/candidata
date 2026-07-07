module Admin
  class ApiTokensController < Admin::BaseController
    # Manages bearer tokens for the public read API (/api/v1).
    # The plaintext token is shown exactly once, on the `created` page.
    def index
      @api_tokens = ApiToken.order(created_at: :desc)
    end

    def new
      @api_token = ApiToken.new
    end

    def create
      @api_token = ApiToken.generate!(
        name: params.require(:api_token)[:name],
        created_by: current_user
      )
      render :created
    rescue ActiveRecord::RecordInvalid => e
      @api_token = e.record
      render :new, status: :unprocessable_entity
    end

    def revoke
      token = ApiToken.find(params[:id])
      token.revoke!
      redirect_to admin_api_tokens_path, notice: "Token "#{token.name}" revoked."
    end
  end
end
