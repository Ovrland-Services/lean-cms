module LeanCms
  class MagicLink < ApplicationRecord
    self.table_name = "lean_cms_magic_links"

    belongs_to :user, class_name: "User"

    PURPOSES = %w[invitation password_reset].freeze
    EXPIRATION_TIMES = {
      "invitation" => 24.hours,
      "password_reset" => 2.hours
    }.freeze

    validates :token, presence: true, uniqueness: true
    validates :purpose, presence: true, inclusion: { in: PURPOSES }
    validates :expires_at, presence: true

    before_validation :generate_token, on: :create
    before_validation :set_expiration, on: :create

    scope :valid, -> { where(used_at: nil).where("expires_at > ?", Time.current) }
    scope :expired, -> { where("expires_at <= ?", Time.current) }
    scope :for_purpose, ->(purpose) { where(purpose: purpose) }

    def self.create_for_invitation(user, created_by_ip: nil)
      create!(
        user: user,
        purpose: "invitation",
        created_by_ip: created_by_ip
      )
    end

    def self.create_for_password_reset(user, created_by_ip: nil)
      where(user: user).for_purpose("password_reset").valid.update_all(used_at: Time.current)

      create!(
        user: user,
        purpose: "password_reset",
        created_by_ip: created_by_ip
      )
    end

    def expired?
      expires_at <= Time.current
    end

    def used?
      used_at.present?
    end

    def valid_for_use?
      !expired? && !used?
    end

    def mark_as_used!(ip_address = nil)
      update!(used_at: Time.current, used_from_ip: ip_address)
    end

    def invitation?
      purpose == "invitation"
    end

    def password_reset?
      purpose == "password_reset"
    end

    private

    def generate_token
      self.token ||= SecureRandom.urlsafe_base64(32)
    end

    def set_expiration
      self.expires_at ||= EXPIRATION_TIMES[purpose].from_now
    end
  end
end
