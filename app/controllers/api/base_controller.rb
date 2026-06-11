module Api
  class BaseController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_user!

    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

    def not_found(exception)
      render json: { error: exception.message, code: "NOT_FOUND" }, status: :not_found
    end

    def unprocessable_entity(exception)
      render json: { error: "Validation failed", errors: exception.record.errors.messages, code: "VALIDATION_ERROR" }, status: :unprocessable_entity
    end

    private

    def json_response(data, meta: nil, status: :ok)
      response_body = { data: data }
      response_body[:meta] = meta if meta.present?
      render json: response_body, status: status
    end

    def paginate(relation, page: 1, per_page: 20)
      page = [page.to_i, 1].max
      per_page = [per_page.to_i, 1].min

      total = relation.count
      records = relation.limit(per_page).offset((page - 1) * per_page)

      meta = {
        total: total,
        page: page,
        per_page: per_page,
        total_pages: (total.to_f / per_page).ceil,
        has_next_page: page < (total.to_f / per_page).ceil,
        has_previous_page: page > 1,
        next_page: page < (total.to_f / per_page).ceil ? page + 1 : nil,
        previous_page: page > 1 ? page - 1 : nil
      }

      [records, meta]
    end
  end
end
