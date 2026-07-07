class SocialMediaAccount < ApplicationRecord
  has_paper_trail on: [:create, :update, :destroy]

  belongs_to :person, touch: true
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
  scope :needs_secondary_verification, -> { where(needs_secondary_verification: true) }
  scope :core_platforms, -> { where(platform: CORE_PLATFORMS) }
  scope :fringe_platforms, -> { where(platform: FRINGE_PLATFORMS) }

  # The universe Junkipedia auto-sync operates on: validated handles with a
  # syncable platform + URL on an active account. Anything outside this scope
  # is intentionally invisible to the sync dashboard counts.
  scope :junkipedia_eligible, -> {
    where(verified: true, account_inactive: false, platform: JunkipediaService::SUPPORTED_PLATFORMS)
      .where.not(url: [nil, ''])
  }
  scope :junkipedia_pending, -> { junkipedia_eligible.where(junkipedia_enqueued_at: nil) }
  scope :junkipedia_unresolved, -> {
    junkipedia_eligible.where.not(junkipedia_enqueued_at: nil).where(junkipedia_channel_id: [nil, ''])
  }
  scope :junkipedia_synced, -> { where.not(junkipedia_channel_id: [nil, '']) }
  scope :junkipedia_errored, -> { where.not(junkipedia_last_error: [nil, '']) }

  after_commit :enqueue_to_junkipedia_on_verification, on: [:create, :update]

  def active?
    !account_inactive?
  end

  def display_name
    handle.present? ? "@#{handle}" : url
  end

  # Four-eyes rule: the user who entered an account may not verify it.
  # Admins are exempt (escape hatch, visible in the audit trail).
  def verifiable_by?(user)
    user.admin? || entered_by_id.nil? || entered_by_id != user.id
  end

  def mark_entered!(user, url: nil, handle: nil)
    # A modification means overwriting real previous data — an existing URL or a
    # verified status. First entry into a blank prepopulated stub is NOT a
    # modification (it used to be, which falsely flagged researcher first
    # entries for secondary verification).
    is_modification = persisted? && ((self.url.present? && self.url != url) || self.research_status == 'verified')

    update!(
      url: url,
      handle: handle,
      entered_by: user,
      entered_at: Time.current,
      research_status: 'entered',
      modified_during_validation: is_modification || modified_during_validation
    )
  end

  def mark_not_found!(user)
    # Check if this is a modification (had URL before, or was verified)
    is_modification = url.present? || research_status == 'verified'

    update!(
      url: nil,
      handle: nil,
      entered_by: user,
      entered_at: Time.current,
      research_status: 'not_found',
      modified_during_validation: is_modification || modified_during_validation
    )
  end

  # Get the most recent URL before it was cleared (from version history)
  def previous_url
    return url if url.present?

    # Look through versions in reverse order to find the last non-nil URL
    versions.reverse_each do |version|
      next unless version.object.present?
      obj = YAML.unsafe_load(version.object)
      return obj['url'] if obj['url'].present?
    end

    nil
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

  # Clear secondary verification flag (called during secondary verification)
  def clear_secondary_verification!
    update!(needs_secondary_verification: false, modified_during_validation: false)
  end

  # Get version count for display
  def version_count
    versions.count
  end

  # Check if there are multiple versions (showing edits have been made)
  def has_revisions?
    versions.count > 1
  end

  def junkipedia_eligible?
    JunkipediaService.supported_platform?(platform) && url.present? && !account_inactive?
  end

  def junkipedia_sync_status
    return :synced  if junkipedia_channel_id.present?
    return :enqueued if junkipedia_enqueued_at.present?
    :pending
  end

  private

  def enqueue_to_junkipedia_on_verification
    return if ENV['JUNKIPEDIA_API_TOKEN'].blank?
    return unless verified?
    return unless saved_change_to_verified? || (previously_new_record? && verified?)
    return unless junkipedia_eligible?
    return if junkipedia_enqueued_at.present?

    EnqueueJunkipediaChannelJob.perform_later(id)
  end

  public

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
