# frozen_string_literal: true

require "spec_helper"

RSpec.describe SmsOpener::Message do
  describe "#otp_code" do
    it "extracts a 6-digit verification code" do
      msg = described_class.new(to: "+15551234567", body: "Your Acme verification code is 849201. Do not share.")
      expect(msg.otp_code).to eq("849201")
    end

    it "extracts code when placed before 'is your verification code'" do
      msg = described_class.new(to: "+15551234567", body: "491028 is your login code for App.")
      expect(msg.otp_code).to eq("491028")
    end

    it "does not falsely extract digits from URLs or phone numbers" do
      msg = described_class.new(
        to: "+15551234567",
        body: "Track your order at https://example.com/orders/982341 or call +1-800-555-9988"
      )
      expect(msg.otp_code).to be_nil
    end
  end

  describe "#urls" do
    it "extracts HTTP and HTTPS links without trailing punctuation" do
      msg = described_class.new(
        to: "+15551234567",
        body: "Sign in at https://app.example.com/magic?token=abc123. Or visit http://status.example.com!"
      )
      expect(msg.urls).to eq([
        "https://app.example.com/magic?token=abc123",
        "http://status.example.com"
      ])
    end
  end

  describe "#encoding and #segments" do
    it "detects GSM-7 and calculates 1 segment for short ASCII messages" do
      msg = described_class.new(to: "+15551234567", body: "Hello from SmsOpener!")
      expect(msg.encoding).to eq("GSM-7")
      expect(msg.character_count).to eq(21)
      expect(msg.segments).to eq(1)
    end

    it "calculates multiple segments for GSM-7 messages over 160 characters" do
      msg = described_class.new(to: "+15551234567", body: "a" * 165)
      expect(msg.encoding).to eq("GSM-7")
      expect(msg.segments).to eq(2)
    end

    it "detects UCS-2 when emojis are present and uses 70/67 char boundaries" do
      msg = described_class.new(to: "+15551234567", body: "Your package has arrived 📦🎉")
      expect(msg.encoding).to eq("UCS-2")
      expect(msg.segments).to eq(1)

      long_unicode = described_class.new(to: "+15551234567", body: "📦" + ("a" * 75))
      expect(long_unicode.encoding).to eq("UCS-2")
      expect(long_unicode.segments).to eq(2)
    end
  end

  describe "#render! and persistence" do
    it "writes sms.html and message.json and loads back via .all and .find" do
      msg = described_class.new(
        to: "+15559876543",
        from: "+15550001111",
        body: "Code: 112233 — click https://example.com/verify",
        media_urls: ["https://example.com/image.png"],
        provider: "twilio",
        metadata: { sid: "SM12345" }
      )
      msg.render!

      expect(File.exist?(msg.filepath)).to be(true)
      expect(File.exist?(msg.json_filepath)).to be(true)

      html = File.read(msg.filepath)
      expect(html).to include("+15559876543")
      expect(html).to include("112233")
      expect(html).to include("https://example.com/verify")
      expect(html).to include("SM12345")

      loaded = described_class.find(msg.id)
      expect(loaded).not_to be_nil
      expect(loaded.to).to eq(["+15559876543"])
      expect(loaded.from).to eq("+15550001111")
      expect(loaded.body).to eq("Code: 112233 — click https://example.com/verify")
      expect(loaded.media_urls).to eq(["https://example.com/image.png"])
      expect(loaded.provider).to eq("twilio")
      expect(loaded.metadata["sid"]).to eq("SM12345")

      expect(described_class.all.map(&:id)).to include(msg.id)

      msg.delete!
      expect(described_class.find(msg.id)).to be_nil
    end
  end
end
