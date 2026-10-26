# frozen_string_literal: true

require "cgi"
require "erb"
require "fileutils"
require "json"
require "securerandom"
require "time"
require "uri"

module SmsOpener
  class Message
    GSM_7_BASIC_CHARS = (
      "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞ\eÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?" \
      "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà"
    ).chars.freeze
    GSM_7_EXTENDED_CHARS = "^{}\\[~]|€\f".chars.freeze

    attr_reader :id, :to, :from, :body, :media_urls, :provider, :metadata, :created_at, :location

    def initialize(
      to:,
      body:,
      from: nil,
      media_urls: [],
      provider: "direct",
      metadata: {},
      id: nil,
      created_at: nil,
      location: nil,
      base_location: nil
    )
      @created_at = parse_time(created_at)
      @id = id || generate_id(@created_at)
      @to = normalize_phone_list(to)
      @from = (from.nil? || from.to_s.strip.empty?) ? SmsOpener.configuration.default_from : from.to_s
      @body = body.to_s
      @media_urls = Array(media_urls).compact.map(&:to_s).reject(&:empty?)
      @provider = provider.to_s
      @metadata = stringify_keys(metadata || {})
      root_dir = base_location || SmsOpener.configuration.resolved_location
      @location = location || File.join(root_dir, @id)
    end

    def to_display
      @to.is_a?(Array) ? @to.join(", ") : @to.to_s
    end

    def otp_code
      # Remove URLs first so we don't match numbers inside links
      cleaned = @body.gsub(%r{https?://\S+}, " ")
      # Remove phone numbers like +15551234567 or 555-123-4567
      cleaned = cleaned.gsub(/\+?\d{1,3}[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/, " ")

      # Look for 4 to 8 digit codes near common verification keywords, or standalone codes
      if (match = cleaned.match(/(?:code|otp|pin|passcode|verification|token|is|:)\s*[:\-]?\s*\b(\d{4,8})\b/i))
        return match[1]
      end

      if (match = cleaned.match(/\b(\d{4,8})\b\s*(?:is your|verification|code|otp|pin)/i))
        return match[1]
      end

      nil
    end

    def urls
      @body.scan(%r{https?://[^\s<>"')]+}).map { |u| u.sub(/[.,;!?]+$/, "") }.uniq
    end

    def encoding
      @body.chars.all? { |ch| GSM_7_BASIC_CHARS.include?(ch) || GSM_7_EXTENDED_CHARS.include?(ch) } ? "GSM-7" : "UCS-2"
    end

    def character_count
      if encoding == "GSM-7"
        @body.chars.sum { |ch| GSM_7_EXTENDED_CHARS.include?(ch) ? 2 : 1 }
      else
        @body.length
      end
    end

    def segments
      count = character_count
      return 0 if count.zero?

      if encoding == "GSM-7"
        count <= 160 ? 1 : (count / 153.0).ceil
      else
        count <= 70 ? 1 : (count / 67.0).ceil
      end
    end

    def filepath
      File.join(@location, "sms.html")
    end

    def json_filepath
      File.join(@location, "message.json")
    end

    def file_uri
      scheme = SmsOpener.configuration.file_uri_scheme || "file"
      "#{scheme}://#{File.expand_path(filepath)}"
    end

    def render!
      FileUtils.mkdir_p(@location)
      File.write(json_filepath, JSON.pretty_generate(to_h))
      File.write(filepath, rendered_html)
      self
    end

    def rendered_html
      template = File.read(template_path)
      ERB.new(template, trim_mode: "-").result(binding)
    end

    def formatted_body_html
      escaped = CGI.escapeHTML(@body)
      # Convert URLs into clickable anchor links
      escaped.gsub(%r{https?://[^\s<>"')]+}) do |match|
        clean_url = match.sub(/[.,;!?]+$/, "")
        trailing = match[clean_url.length..]
        %(<a href="#{clean_url}" target="_blank" rel="noopener noreferrer" class="sms-link">#{clean_url}</a>#{trailing})
      end.gsub("\n", "<br>")
    end

    def to_h
      {
        "id" => @id,
        "to" => @to,
        "to_display" => to_display,
        "from" => @from,
        "body" => @body,
        "media_urls" => @media_urls,
        "provider" => @provider,
        "metadata" => @metadata,
        "otp_code" => otp_code,
        "urls" => urls,
        "encoding" => encoding,
        "character_count" => character_count,
        "segments" => segments,
        "created_at" => @created_at.iso8601(3),
        "filepath" => filepath
      }
    end

    def delete!
      FileUtils.rm_rf(@location) if @location && Dir.exist?(@location)
    end

    class << self
      def all
        base_dir = SmsOpener.configuration.resolved_location
        return [] unless Dir.exist?(base_dir)

        Dir.glob(File.join(base_dir, "*", "message.json"))
           .filter_map { |json_path| load_from_json(json_path) }
           .sort_by { |msg| [msg.created_at, msg.id] }
           .reverse
      end

      def find(id)
        safe_id = File.basename(id.to_s)
        return nil if safe_id.empty? || safe_id == "." || safe_id == ".."

        json_path = File.join(SmsOpener.configuration.resolved_location, safe_id, "message.json")
        return nil unless File.exist?(json_path)

        load_from_json(json_path)
      end

      def clear!
        base_dir = SmsOpener.configuration.resolved_location
        return unless Dir.exist?(base_dir)

        Dir.children(base_dir).each do |entry|
          path = File.join(base_dir, entry)
          FileUtils.rm_rf(path) if File.directory?(path)
        end
      end

      def load_from_json(json_path)
        data = JSON.parse(File.read(json_path))
        new(
          id: data["id"],
          to: data["to"],
          from: data["from"],
          body: data["body"],
          media_urls: data["media_urls"] || [],
          provider: data["provider"] || "direct",
          metadata: data["metadata"] || {},
          created_at: data["created_at"],
          location: File.dirname(json_path)
        )
      rescue JSON::ParserError, StandardError
        nil
      end
    end

    private

    def template_path
      File.expand_path("templates/sms.html.erb", __dir__)
    end

    def parse_time(value)
      return Time.now if value.nil?
      return value if value.is_a?(Time)

      Time.parse(value.to_s)
    rescue ArgumentError
      Time.now
    end

    def generate_id(time)
      "#{time.strftime('%Y%m%d_%H%M%S_%L')}_#{SecureRandom.hex(4)}"
    end

    def normalize_phone_list(to)
      case to
      when Array
        to.map(&:to_s)
      else
        [to.to_s]
      end
    end

    def stringify_keys(hash)
      hash.each_with_object({}) do |(k, v), acc|
        acc[k.to_s] = v
      end
    end
  end
end
