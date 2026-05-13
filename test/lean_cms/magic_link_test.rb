require_relative "../test_helper"

class LeanCms::MagicLinkTest < ActiveSupport::TestCase
  setup do
    User.delete_all
    LeanCms::MagicLink.delete_all
    @user = User.create!(
      email_address: "admin@example.com",
      password: "secret123",
      active: true,
      is_super_admin: true
    )
  end

  test "invitation expires 24 hours from creation" do
    link = LeanCms::MagicLink.create_for_invitation(@user)
    assert link.invitation?
    assert_in_delta 24.hours.from_now.to_i, link.expires_at.to_i, 5
  end

  test "password reset expires 2 hours from creation" do
    link = LeanCms::MagicLink.create_for_password_reset(@user)
    assert link.password_reset?
    assert_in_delta 2.hours.from_now.to_i, link.expires_at.to_i, 5
  end

  test "creating a password reset invalidates prior unused resets for the same user" do
    first  = LeanCms::MagicLink.create_for_password_reset(@user)
    second = LeanCms::MagicLink.create_for_password_reset(@user)

    assert first.reload.used?, "first link should be marked used when second is created"
    refute second.used?
  end

  test "mark_as_used! is idempotent on the active link" do
    link = LeanCms::MagicLink.create_for_invitation(@user)
    refute link.used?
    link.mark_as_used!("127.0.0.1")
    assert link.used?
    assert_equal "127.0.0.1", link.used_from_ip
  end

  test "valid_for_use? requires not-expired and not-used" do
    link = LeanCms::MagicLink.create_for_invitation(@user)
    assert link.valid_for_use?

    link.update!(expires_at: 1.minute.ago)
    refute link.valid_for_use?
  end
end
