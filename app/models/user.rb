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

  validates :role, inclusion: { in: ROLES }

  scope :admins, -> { where(role: 'admin') }
  scope :researchers, -> { where(role: 'researcher') }

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
      # Create a brand new user
      user = create(
        email: auth.info.email,
        password: Devise.friendly_token[0, 20],
        name: auth.info.name,
        provider: auth.provider,
        uid: auth.uid
      )
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
      avatar.purge if avatar.attached?

      downloaded_image = URI.open(url)
      avatar.attach(
        io: downloaded_image,
        filename: "avatar_#{id}.jpg",
        content_type: downloaded_image.content_type
      )
    rescue OpenURI::HTTPError, SocketError => e
      Rails.logger.warn "Failed to download avatar: #{e.message}"
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
