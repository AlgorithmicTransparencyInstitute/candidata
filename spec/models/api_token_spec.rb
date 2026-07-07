require 'rails_helper'

RSpec.describe ApiToken, type: :model do
  describe ".generate!" do
    it "creates a token with the cnd_live_ prefix and exposes the plaintext once" do
      token = ApiToken.generate!(name: "test-service")

      expect(token).to be_persisted
      expect(token.raw_token).to match(/\Acnd_live_\h{24}\z/)
      expect(token.token_digest).to eq(Digest::SHA256.hexdigest(token.raw_token))
      # plaintext is never stored
      expect(token.reload.attributes.values).not_to include(token.raw_token)
    end

    it "records the creating user" do
      admin = create(:user, :admin)
      token = ApiToken.generate!(name: "svc", created_by: admin)
      expect(token.created_by).to eq(admin)
    end

    it "requires a name" do
      expect { ApiToken.generate!(name: "") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe ".authenticate" do
    it "returns the token for a valid plaintext" do
      token = ApiToken.generate!(name: "svc")
      expect(ApiToken.authenticate(token.raw_token)).to eq(token)
    end

    it "returns nil for blank, unknown, or revoked tokens" do
      token = ApiToken.generate!(name: "svc")
      raw = token.raw_token

      expect(ApiToken.authenticate(nil)).to be_nil
      expect(ApiToken.authenticate("")).to be_nil
      expect(ApiToken.authenticate("cnd_live_ffffffffffffffffffffffff")).to be_nil

      token.revoke!
      expect(ApiToken.authenticate(raw)).to be_nil
    end
  end

  describe "#touch_last_used!" do
    it "stamps last_used_at, but at most once per minute" do
      token = ApiToken.generate!(name: "svc")
      token.touch_last_used!
      first = token.reload.last_used_at
      expect(first).to be_present

      token.touch_last_used!
      expect(token.reload.last_used_at).to eq(first)

      token.update_column(:last_used_at, 2.minutes.ago)
      token.touch_last_used!
      expect(token.reload.last_used_at).to be > first - 3.minutes
      expect(token.reload.last_used_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe "#revoke! / .active" do
    it "excludes revoked tokens from the active scope" do
      token = ApiToken.generate!(name: "svc")
      expect(ApiToken.active).to include(token)
      token.revoke!
      expect(token).to be_revoked
      expect(ApiToken.active).not_to include(token)
    end
  end
end
