class User < ApplicationRecord
  ROLES = %w[admin researcher researcher_assistant].freeze

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :omniauthable, omniauth_providers: [:google_oauth2]

  has_one_attached :avatar

  validates :role, inclusion: { in: ROLES }

  def self.from_omniauth(auth)
    user = where(provider: auth.provider, uid: auth.uid).first_or_create do |u|
      u.email = auth.info.email
      u.password = Devise.friendly_token[0, 20]
      u.name = auth.info.name
    end

    # Download and attach avatar if provided and not already attached
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

  def researcher_assistant?
    role == 'researcher_assistant'
  end

  def can_manage_users?
    admin?
  end

  def can_assign_tasks?
    admin? || researcher?
  end
end
