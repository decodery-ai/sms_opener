# frozen_string_literal: true

require "launchy"

module SmsOpener
  class DeliveryMethod
    class InvalidOption < StandardError; end

    attr_reader :settings

    def initialize(options = {})
      @settings = {
        location: SmsOpener.configuration.resolved_location,
        launch_browser: SmsOpener.configuration.launch_browser
      }.merge(options)
    end

    def deliver!(message_or_attributes = nil, **kwargs)
      message = build_message(message_or_attributes, kwargs)

      instrument_delivery(message) do
        message.render!
        log_delivery(message)
        open_in_browser(message) if should_launch_browser?
      end

      message
    end

    private

    def build_message(message_or_attributes, kwargs)
      return message_or_attributes if message_or_attributes.is_a?(SmsOpener::Message)

      attrs = if message_or_attributes.is_a?(Hash)
                symbolize_keys(message_or_attributes).merge(kwargs)
              elsif message_or_attributes.respond_to?(:to) && message_or_attributes.respond_to?(:body)
                {
                  to: message_or_attributes.to,
                  from: message_or_attributes.respond_to?(:from) ? message_or_attributes.from : nil,
                  body: message_or_attributes.body,
                  media_urls: message_or_attributes.respond_to?(:media_urls) ? message_or_attributes.media_urls : []
                }.merge(kwargs)
              else
                kwargs
              end

      to = attrs.delete(:to)
      body = attrs.delete(:body)
      raise InvalidOption, "Both :to and :body are required to deliver an SMS" if to.nil? || body.nil?

      from = attrs.delete(:from)
      media_urls = attrs.delete(:media_urls) || attrs.delete(:media_url) || []
      provider = attrs.delete(:provider) || "direct"
      id = attrs.delete(:id)
      created_at = attrs.delete(:created_at)
      explicit_metadata = attrs.delete(:metadata) || {}
      metadata = explicit_metadata.merge(attrs)

      SmsOpener::Message.new(
        to: to,
        from: from,
        body: body,
        media_urls: media_urls,
        provider: provider,
        metadata: metadata,
        id: id,
        created_at: created_at,
        base_location: @settings[:location]
      )
    end

    def should_launch_browser?
      Boolean(@settings[:launch_browser])
    end

    def open_in_browser(message)
      Launchy.open(message.file_uri)
    rescue StandardError => e
      warn "[SmsOpener] Failed to open browser via Launchy: #{e.message} (file saved at #{message.filepath})"
    end

    def log_delivery(message)
      return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

      otp_info = message.otp_code ? " [OTP: #{message.otp_code}]" : ""
      Rails.logger.info(
        "[SmsOpener] Captured SMS (#{message.provider}) From: #{message.from} -> To: #{message.to_display}#{otp_info} | " \
        "Body: #{message.body.inspect} | Saved to: #{message.filepath}"
      )
    end

    def instrument_delivery(message, &block)
      if defined?(ActiveSupport::Notifications)
        ActiveSupport::Notifications.instrument(
          "deliver.sms_opener",
          message: message,
          to: message.to,
          from: message.from,
          body: message.body,
          provider: message.provider,
          &block
        )
      else
        yield
      end
    end

    def symbolize_keys(hash)
      hash.each_with_object({}) do |(k, v), acc|
        acc[k.to_sym] = v
      end
    end

    def Boolean(val) # rubocop:disable Naming/MethodName
      return false if val.nil? || val == false || val.to_s.strip.casecmp("false").zero?

      true
    end
  end
end
