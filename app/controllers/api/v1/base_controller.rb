module Api
  module V1
    # Public read-only API. Header-only Bearer token auth (ApiToken); no
    # sessions, CSRF, or Devise involvement. Conventions match the internal
    # /api (envelope, error codes, pagination shape) but serializers are
    # independent — this contract must stay stable for external consumers.
    class BaseController < ActionController::API
      include Api::V1::Serializers

      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 500
      RATE_LIMIT_PER_MINUTE = 300

      before_action :authenticate_api_token!
      before_action :enforce_rate_limit!

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      private

      def authenticate_api_token!
        raw = request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]
        @api_token = ApiToken.authenticate(raw)

        if @api_token
          @api_token.touch_last_used!
        else
          render json: { error: "Invalid or missing API token", code: "UNAUTHORIZED" },
                 status: :unauthorized
        end
      end

      # Fixed-window per-token throttle. Rails.cache increment returns nil on
      # stores without counters (test null_store) — then the limit is a no-op.
      def enforce_rate_limit!
        window = Time.current.to_i / 60
        count = Rails.cache.increment("api_v1_rate:#{@api_token.id}:#{window}", 1, expires_in: 2.minutes)
        return if count.nil? || count <= RATE_LIMIT_PER_MINUTE

        render json: { error: "Rate limit exceeded (#{RATE_LIMIT_PER_MINUTE}/minute)", code: "RATE_LIMITED" },
               status: :too_many_requests
      end

      def render_not_found(exception)
        render json: { error: exception.message, code: "NOT_FOUND" }, status: :not_found
      end

      def json_response(data, meta: nil, status: :ok)
        body = { data: data }
        body[:meta] = meta if meta.present?
        render json: body, status: status
      end

      def paginate(relation)
        page = params[:page].to_i.clamp(1, 1_000_000)
        per_page = (params[:per_page].presence || DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)

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

      # Parses ?updated_since= as ISO8601. On bad input renders 400 and returns
      # nil — callers must bail with `return if performed?` after calling.
      def updated_since_param
        return nil if params[:updated_since].blank?

        Time.iso8601(params[:updated_since])
      rescue ArgumentError
        render json: { error: "updated_since must be an ISO8601 timestamp", code: "INVALID_PARAM" },
               status: :bad_request
        nil
      end
    end
  end
end
