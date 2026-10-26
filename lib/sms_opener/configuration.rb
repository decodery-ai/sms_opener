# frozen_string_literal: true

module SmsOpener
  class Configuration
    attr_accessor :location, :launch_browser, :intercept_twilio, :default_from, :file_uri_scheme

    def initialize
      @location = default_location
      @launch_browser = ENV.fetch("SMS_OPENER_LAUNCH_BROWSER", "true") != "false"
      @intercept_twilio = true
      @default_from = "+15550000000"
      @file_uri_scheme = nil
    end

    def resolved_location
      @location || default_location
    end

    private

    def default_location
      if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
        Rails.root.join("tmp", "sms_opener").to_s
      else
        File.join(Dir.pwd, "tmp", "sms_opener")
      end
    end
  end
end
