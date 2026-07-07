require 'rails_helper'

RSpec.describe "Admin API tokens", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:researcher) { create(:user) }

  it "blocks non-admins" do
    sign_in researcher
    get admin_api_tokens_path
    expect(response).to redirect_to(root_path)
  end

  context "as admin" do
    before { sign_in admin }

    it "lists tokens" do
      token = ApiToken.generate!(name: "listed-service")
      get admin_api_tokens_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("listed-service")
      expect(response.body).not_to include(token.raw_token)
    end

    it "creates a token and shows the plaintext exactly once" do
      post admin_api_tokens_path, params: { api_token: { name: "new-service" } }
      expect(response).to have_http_status(:ok)

      token = ApiToken.order(:id).last
      expect(token.name).to eq("new-service")
      expect(response.body).to include("cnd_live_") # plaintext displayed on the created page

      get admin_api_tokens_path # never displayed again
      expect(response.body).not_to match(/cnd_live_\h{24}/)
    end

    it "rejects a blank name" do
      expect {
        post admin_api_tokens_path, params: { api_token: { name: "" } }
      }.not_to change(ApiToken, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "revokes a token" do
      token = ApiToken.generate!(name: "doomed")
      post revoke_admin_api_token_path(token)
      expect(token.reload).to be_revoked
      expect(response).to redirect_to(admin_api_tokens_path)
      expect(flash[:notice]).to include("doomed")
    end
  end
end
