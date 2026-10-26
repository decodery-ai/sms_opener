# frozen_string_literal: true

require "securerandom"
require "time"

module SmsOpener
  module Interceptors
    module TwilioInterceptor
      FallbackMessageInstance = Struct.new(
        :sid, :account_sid, :to, :from, :messaging_service_sid, :body,
        :status, :direction, :num_segments, :num_media, :date_created, :date_updated,
        keyword_init: true
      )

      module MessageListPatch
        def create(to: nil, from: nil, body: nil, media_url: nil, messaging_service_sid: nil, **kwargs)
          return super unless SmsOpener.configuration.intercept_twilio

          media_list = Array(media_url).compact.map(&:to_s).reject(&:empty?)
          sid_prefix = media_list.empty? ? "SM" : "MM"
          sid = "#{sid_prefix}#{SecureRandom.hex(16)}"

          solution = instance_variable_defined?(:@solution) ? instance_variable_get(:@solution) : {}
          account_sid = (solution && solution[:account_sid]) || "AC00000000000000000000000000000000"

          sender = from || messaging_service_sid || SmsOpener.configuration.default_from
          effective_body = body || (kwargs[:content_sid] ? "[Twilio Content Template: #{kwargs[:content_sid]}]" : "")

          extra_metadata = {
            "sid" => sid,
            "account_sid" => account_sid,
            "status" => "queued",
            "direction" => "outbound-api"
          }
          extra_metadata["messaging_service_sid"] = messaging_service_sid if messaging_service_sid
          kwargs.each do |k, v|
            extra_metadata[k.to_s] = v unless v.nil?
          end

          captured_message = SmsOpener.deliver(
            to: to,
            from: sender,
            body: effective_body,
            media_urls: media_list,
            provider: "twilio",
            metadata: extra_metadata
          )

          now_rfc2822 = Time.now.rfc2822
          payload = {
            "sid" => sid,
            "account_sid" => account_sid,
            "to" => captured_message.to_display,
            "from" => sender,
            "messaging_service_sid" => messaging_service_sid,
            "body" => captured_message.body,
            "status" => "queued",
            "direction" => "outbound-api",
            "num_segments" => captured_message.segments.to_s,
            "num_media" => media_list.size.to_s,
            "date_created" => now_rfc2822,
            "date_updated" => now_rfc2822,
            "date_sent" => now_rfc2822,
            "error_code" => nil,
            "error_message" => nil
          }

          if defined?(::Twilio::REST::Api::V2010::AccountContext::MessageInstance) && instance_variable_defined?(:@version)
            ::Twilio::REST::Api::V2010::AccountContext::MessageInstance.new(
              instance_variable_get(:@version),
              payload,
              account_sid: account_sid
            )
          else
            FallbackMessageInstance.new(
              sid: sid,
              account_sid: account_sid,
              to: captured_message.to_display,
              from: sender,
              messaging_service_sid: messaging_service_sid,
              body: captured_message.body,
              status: "queued",
              direction: "outbound-api",
              num_segments: captured_message.segments.to_s,
              num_media: media_list.size.to_s,
              date_created: Time.now,
              date_updated: Time.now
            )
          end
        end
      end

      class << self
        def install!
          return false unless defined?(::Twilio::REST)

          target = ::Twilio::REST::Api::V2010::AccountContext::MessageList
          unless target.ancestors.include?(MessageListPatch)
            target.prepend(MessageListPatch)
          end
          true
        rescue NameError
          false
        end

        def installed?
          return false unless defined?(::Twilio::REST)

          ::Twilio::REST::Api::V2010::AccountContext::MessageList.ancestors.include?(MessageListPatch)
        rescue NameError
          false
        end
      end
    end
  end
end

SmsOpener::Interceptors::TwilioInterceptor.install!
