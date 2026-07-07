# Bearer tokens for the public read API (/api/v1). Plaintext is generated
# once and never stored — only its SHA-256 digest. Lookup is by unique digest
# index (the standard API-token pattern: a preimage-resistant digest makes
# timing attacks on the index lookup impractical).
class ApiToken < ApplicationRecord
  TOKEN_PREFIX = "cnd_live_".freeze

  belongs_to :created_by, class_name: "User", optional: true

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  # Plaintext token, present only on the instance returned by generate!.
  attr_reader :raw_token

  def self.generate!(name:, created_by: nil)
    raw = TOKEN_PREFIX + SecureRandom.hex(12)
    token = create!(name: name, created_by: created_by, token_digest: digest(raw))
    token.instance_variable_set(:@raw_token, raw)
    token
  end

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw)
  end

  def self.authenticate(raw)
    return nil if raw.blank?

    active.find_by(token_digest: digest(raw))
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  # Throttled to one write per minute to avoid write amplification on
  # high-volume consumers. update_column: no validations, no updated_at bump,
  # no PaperTrail noise.
  def touch_last_used!
    return if last_used_at && last_used_at > 1.minute.ago

    update_column(:last_used_at, Time.current)
  end
end
