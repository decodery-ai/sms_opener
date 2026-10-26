# frozen_string_literal: true

require_relative "sms_opener/version"
require_relative "sms_opener/configuration"
require_relative "sms_opener/message"
require_relative "sms_opener/delivery_method"

module SmsOpener
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      if configuration.intercept_twilio && defined?(SmsOpener::Interceptors::TwilioInterceptor)
        SmsOpener::Interceptors::TwilioInterceptor.install!
      end
      configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def deliver(message_or_attributes = nil, **kwargs)
      DeliveryMethod.new.deliver!(message_or_attributes, **kwargs)
    end

    def messages
      Message.all
    end

    def find(id)
      Message.find(id)
    end

    def clear!
      Message.clear!
    end
  end
end

require_relative "sms_opener/interceptors/twilio_interceptor" if File.exist?(File.expand_path("sms_opener/interceptors/twilio_interceptor.rb", __dir__))
require_relative "sms_opener/railtie" if defined?(Rails::Railtie) && File.exist?(File.expand_path("sms_opener/railtie.rb", __dir__))
require_relative "sms_opener/engine" if defined?(Rails::Engine) && File.exist?(File.expand_path("sms_opener/engine.rb", __dir__))
