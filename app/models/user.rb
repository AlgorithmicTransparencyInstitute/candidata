class User < ApplicationRecord
  has_paper_trail

  ROLES = %w[admin researcher].freeze

  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :omniauthable, omniauth_providers: [:google_oauth2, :entra_id]

  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_fill: [100, 100]
  end
  validates :avatar, content_type: ['image/png', 'image/jpeg', 'image/gif', 'image/webp'],
                     size: { less_than: 5.megabytes, message: 'must be less than 5MB' },
                     if: -> { avatar.attached? }

  has_many :assignments, dependent: :destroy
  has_many :assigned_people, through: :assignments, source: :person
  has_many :assignments_given, class_name: 'Assignment', foreign_key: 'assigned_by_id', dependent: :nullify
  has_many :entered_accounts, class_name: 'SocialMediaAccount', foreign_key: 'entered_by_id'
  has_many :verified_accounts, class_name: 'SocialMediaAccount', foreign_key: 'verified_by_id'
  # Both FKs from demographic_verifications point here and are NO ACTION at the
  # DB level, so without these a researcher who has recorded any determination
  # could never be deleted. Nullify: the determination stands, we just lose the
  # attribution — PaperTrail still has the history.
  has_many :demographic_verifications, foreign_key: 'verified_by_id', dependent: :nullify
  has_many :reviewed_people, class_name: 'Person', foreign_key: 'demographics_reviewed_by_id', dependent: :nullify
  has_many :visits, class_name: 'Ahoy::Visit', dependent: :destroy

  belongs_to :deactivated_by, class_name: 'User', optional: true

  validates :role, inclusion: { in: ROLES }

  scope :admins, -> { where(role: 'admin') }
  scope :researchers, -> { where(role: 'researcher') }

  # Researchers arrive and leave in cohorts. Deactivation is a soft state:
  # their work stays attributed to them (entered_by, verified_by, PaperTrail
  # whodunnit), they just stop appearing in pickers and stop being able to
  # sign in.
  #
  # `researchers` deliberately still means ALL researchers — stats and history
  # need the full set. Anywhere a human is being CHOSEN, use
  # `active_researchers`.
  scope :active, -> { where(deactivated_at: nil) }
  scope :inactive, -> { where.not(deactivated_at: nil) }
  scope :active_researchers, -> { researchers.active }
  scope :in_cohort, ->(cohort) { where(cohort: cohort) }

  def active?
    deactivated_at.nil?
  end

  def deactivated?
    !active?
  end

  # Devise checks this on sign-in AND on every authenticated request, so
  # deactivating someone ends their current session too — which is the point.
  # Without this, "inactive" would be cosmetic and a departed researcher would
  # keep their access to production data.
  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :account_deactivated
  end

  def deactivate!(by: nil)
    update!(deactivated_at: Time.current, deactivated_by: by)
  end

  def reactivate!
    update!(deactivated_at: nil, deactivated_by: nil)
  end

  # Work that would be stranded by deactivating this person. Surfaced before
  # an admin confirms, so a cohort rollover doesn't quietly park assignments
  # with someone who can no longer log in.
  def open_assignments_count
    assignments.active.count
  end

  def self.from_omniauth(auth)
    # First check if there's an existing user with this provider/uid
    user = find_by(provider: auth.provider, uid: auth.uid)

    # If not found by provider/uid, check for an invited user by email
    user ||= find_by(email: auth.info.email)

    if user
      # Update OAuth credentials if not yet set
      if user.provider.blank?
        user.update(provider: auth.provider, uid: auth.uid)
      end
      # Accept invitation if pending
      if user.invitation_token.present? && !user.invitation_accepted?
        user.accept_invitation!
      end
      user.update(name: auth.info.name) if user.name.blank?
    else
      # Candidata is invitation-only: an OAuth identity we've never invited
      # does not get an account. This used to be enforced by accident — the
      # record was built without a role, failed the ROLES validation, and the
      # user saw "Role is not included in the list". Same outcome, but stated
      # on purpose so nobody "fixes" the validation and opens self-registration
      # to anyone with a Google account.
      user = new(email: auth.info.email, name: auth.info.name,
                 provider: auth.provider, uid: auth.uid)
      user.errors.add(:base, 'No Candidata account exists for this email address. Ask an administrator for an invitation.')
      return user
    end

    # Always update avatar from OAuth provider if available
    if auth.info.image.present?
      user.attach_avatar_from_url(auth.info.image)
    end

    user
  end

  def attach_avatar_from_url(url)
    return if url.blank?

    require 'open-uri'
    begin
      # Purge old avatar if exists to replace with new one
      begin
        avatar.purge if avatar.attached?
      rescue => e
        Rails.logger.warn "Failed to purge old avatar: #{e.message}"
      end

      downloaded_image = URI.open(url)
      avatar.attach(
        io: downloaded_image,
        filename: "avatar_#{id}.jpg",
        content_type: downloaded_image.content_type
      )
    rescue OpenURI::HTTPError, SocketError, StandardError => e
      Rails.logger.warn "Failed to download/attach avatar: #{e.message}"
    end
  end

  def admin?
    role == 'admin'
  end

  def researcher?
    role == 'researcher'
  end

  def can_manage_users?
    admin?
  end

  def can_assign_tasks?
    admin?
  end

  def pending_assignments
    assignments.active
  end

  def data_collection_assignments
    assignments.data_collection.active
  end

  def data_validation_assignments
    assignments.data_validation.active
  end
end
