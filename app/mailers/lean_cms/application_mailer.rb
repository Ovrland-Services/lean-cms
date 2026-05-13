module LeanCms
  class ApplicationMailer < ActionMailer::Base
    default from: -> { LeanCms.mailer_from }
    layout "mailer"
  end
end
