# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "sms_opener"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around(:each) do |example|
    Dir.mktmpdir("sms_opener_spec") do |tmpdir|
      SmsOpener.reset_configuration!
      SmsOpener.configure do |c|
        c.location = tmpdir
        c.launch_browser = false
      end
      example.run
    end
  end
end
