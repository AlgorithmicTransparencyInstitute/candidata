module Api
  # Shared behavior for the internal JSON API.
  #
  # Auth: Devise session (browser clients send X-CSRF-Token on mutations —
  # forgery protection stays ON; without a token the session is nulled and
  # authenticate_user! returns 401). Reads require sign-in; mutations
  # require admin via require_admin! in subclasses.
  class BaseController < ApplicationController
    before_action :authenticate_user!
    skip_before_action :track_ahoy_visit, raise: false

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
    rescue_from ActionController::ParameterMissing, with: :render_param_missing

    private

    def require_admin!
      return if current_user&.admin?

      render json: { error: "Admin access required", code: "FORBIDDEN" }, status: :forbidden
    end

    def render_not_found(exception)
      render json: { error: exception.message, code: "NOT_FOUND" }, status: :not_found
    end

    def render_unprocessable(exception)
      render json: {
        error: "Validation failed",
        errors: exception.record.errors.messages,
        code: "VALIDATION_ERROR"
      }, status: :unprocessable_entity
    end

    def render_param_missing(exception)
      render json: { error: exception.message, code: "PARAM_MISSING" }, status: :bad_request
    end

    def json_response(data, meta: nil, status: :ok)
      body = { data: data }
      body[:meta] = meta if meta.present?
      render json: body, status: status
    end

    def paginate(relation)
      page = params[:page].to_i.clamp(1, 1_000_000)
      per_page = (params[:per_page].presence || 25).to_i.clamp(1, 100)

      total = relation.count
      total_pages = (total.to_f / per_page).ceil
      records = relation.limit(per_page).offset((page - 1) * per_page)

      meta = {
        total: total,
        page: page,
        per_page: per_page,
        total_pages: total_pages,
        has_next_page: page < total_pages,
        has_previous_page: page > 1
      }
      [records, meta]
    end
  end
end
