class User < ApplicationRecord
  has_paper_trail

  ROLES = %w[admin researcher].freeze

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :omniauthable, omniauth_providers: [:google_oauth2, :entra_id]

  has_one_attached :avatar
  has_many :assignments, dependent: :destroy
  has_many :assigned_people, through: :assignments, source: :person
  has_many :assignments_given, class_name: 'Assignment', foreign_key: 'assigned_by_id', dependent: :nullify
  has_many :entered_accounts, class_name: 'SocialMediaAccount', foreign_key: 'entered_by_id'
  has_many :verified_accounts, class_name: 'SocialMediaAccount', foreign_key: 'verified_by_id'

  validates :role, inclusion: { in: ROLES }

  scope :admins, -> { where(role: 'admin') }
  scope :researchers, -> { where(role: 'researcher') }

  def self.from_omniauth(auth)
    user = where(provider: auth.provider, uid: auth.uid).first_or_create do |u|
      u.email = auth.info.email
      u.password = Devise.friendly_token[0, 20]
      u.name = auth.info.name
    end

    if auth.info.image.present? && !user.avatar.attached?
      user.attach_avatar_from_url(auth.info.image)
    end

    user
  end

  def attach_avatar_from_url(url)
    return if url.blank?

    require 'open-uri'
    begin
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

  def research_assignments
    assignments.research.active
  end

  def verification_assignments
    assignments.verification.active
  end
end
