class SocialMediaAccount < ApplicationRecord
  belongs_to :person

  PLATFORMS = %w[Facebook Twitter Instagram YouTube TikTok TruthSocial Gettr Rumble Telegram Threads].freeze
  CHANNEL_TYPES = ['Campaign', 'Official Office', 'Personal'].freeze
  STATUSES = ['Reviewed', 'To verify', 'Not reviewed', 'Inactive'].freeze

  validates :platform, presence: true, inclusion: { in: PLATFORMS, message: "%{value} is not a valid platform" }
  validates :channel_type, inclusion: { in: CHANNEL_TYPES, allow_blank: true }
  validates :handle, uniqueness: { scope: [:person_id, :platform], allow_blank: true }

  scope :active, -> { where(account_inactive: false) }
  scope :inactive, -> { where(account_inactive: true) }
  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }
  scope :by_platform, ->(platform) { where(platform: platform) }
  scope :campaign, -> { where(channel_type: 'Campaign') }
  scope :official, -> { where(channel_type: 'Official Office') }
  scope :personal, -> { where(channel_type: 'Personal') }

  def active?
    !account_inactive?
  end

  def display_name
    handle.present? ? "@#{handle}" : url
  end
end
