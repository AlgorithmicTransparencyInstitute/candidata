class SocialMediaAccount < ApplicationRecord
  has_paper_trail on: [:create, :update, :destroy]

  belongs_to :person
  belongs_to :entered_by, class_name: 'User', optional: true
  belongs_to :verified_by, class_name: 'User', optional: true

  PLATFORMS = %w[Facebook Twitter Instagram YouTube TikTok BlueSky TruthSocial Gettr Rumble Telegram Threads].freeze
  CORE_PLATFORMS = %w[Facebook Twitter Instagram YouTube TikTok BlueSky].freeze
  FRINGE_PLATFORMS = %w[TruthSocial Gettr Rumble Telegram Threads].freeze
  CHANNEL_TYPES = ['Campaign', 'Official Office', 'Personal'].freeze
  STATUSES = ['Reviewed', 'To verify', 'Not reviewed', 'Inactive'].freeze
  RESEARCH_STATUSES = %w[not_started entered not_found verified rejected revised].freeze

  validates :platform, presence: true, inclusion: { in: PLATFORMS, message: "%{value} is not a valid platform" }
  validates :channel_type, inclusion: { in: CHANNEL_TYPES, allow_blank: true }
  validates :handle, uniqueness: { scope: [:person_id, :platform, :channel_type], allow_blank: true }
  validates :research_status, inclusion: { in: RESEARCH_STATUSES }, allow_nil: true

  scope :active, -> { where(account_inactive: false) }
  scope :inactive, -> { where(account_inactive: true) }
  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }
  scope :by_platform, ->(platform) { where(platform: platform) }
  scope :campaign, -> { where(channel_type: 'Campaign') }
  scope :official, -> { where(channel_type: 'Official Office') }
  scope :personal, -> { where(channel_type: 'Personal') }
  scope :pre_populated, -> { where(pre_populated: true) }
  scope :needs_research, -> { where(research_status: 'not_started', pre_populated: true) }
  scope :needs_verification, -> { where(research_status: %w[entered not_found revised]) }
  scope :core_platforms, -> { where(platform: CORE_PLATFORMS) }
  scope :fringe_platforms, -> { where(platform: FRINGE_PLATFORMS) }

  def active?
    !account_inactive?
  end

  def display_name
    handle.present? ? "@#{handle}" : url
  end

  def mark_entered!(user, url: nil, handle: nil)
    update!(
      url: url,
      handle: handle,
      entered_by: user,
      entered_at: Time.current,
      research_status: 'entered'
    )
  end

  def mark_not_found!(user)
    update!(
      entered_by: user,
      entered_at: Time.current,
      research_status: 'not_found'
    )
  end

  def reset_status!(user)
    update!(
      url: nil,
      handle: nil,
      entered_by: user,
      entered_at: Time.current,
      research_status: 'not_started'
    )
  end

  def verify!(user, notes: nil)
    update!(
      verified_by: user,
      verified_at: Time.current,
      research_status: 'verified',
      verified: true,
      verification_notes: notes
    )
  end

  def reject!(user, notes: nil)
    update!(
      verified_by: user,
      verified_at: Time.current,
      research_status: 'rejected',
      verification_notes: notes
    )
  end

  # When a verifier revises a record, it needs re-verification
  def revise!(user, url: nil, handle: nil, notes: nil)
    update!(
      url: url || self.url,
      handle: handle || self.handle,
      verified_by: user,
      verified_at: Time.current,
      research_status: 'revised',
      verification_notes: notes,
      verified: false  # Unverify since it was revised
    )
  end

  # Helper to check if this account needs verification
  def needs_verification?
    research_status.in?(%w[entered not_found revised])
  end

  # Get version count for display
  def version_count
    versions.count
  end

  # Check if there are multiple versions (showing edits have been made)
  def has_revisions?
    versions.count > 1
  end

  def self.prepopulate_for_person!(person, platforms: CORE_PLATFORMS, channel_type: 'Campaign')
    platforms.each do |platform|
      existing = person.social_media_accounts.find_by(platform: platform, channel_type: channel_type)
      next if existing

      person.social_media_accounts.create!(
        platform: platform,
        channel_type: channel_type,
        pre_populated: true,
        research_status: 'not_started'
      )
    end
  end
end
