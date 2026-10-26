# frozen_string_literal: true

require "rails/railtie"
require "active_support/ordered_options"

module SmsOpener
  class Railtie < ::Rails::Railtie
    config.sms_opener = ActiveSupport::OrderedOptions.new

    initializer "sms_opener.configure" do |app|
      app.config.sms_opener.each do |key, value|
        setter = :"#{key}="
        SmsOpener.configuration.public_send(setter, value) if SmsOpener.configuration.respond_to?(setter)
      end
    end

    config.after_initialize do
      if SmsOpener.configuration.intercept_twilio
        SmsOpener::Interceptors::TwilioInterceptor.install!
      end
    end
  end
end
