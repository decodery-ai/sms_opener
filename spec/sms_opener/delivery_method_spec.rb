# frozen_string_literal: true

require "spec_helper"

RSpec.describe SmsOpener::DeliveryMethod do
  describe "#deliver! and SmsOpener.deliver" do
    it "saves the message and opens it in the browser with Launchy when launch_browser is true" do
      SmsOpener.configuration.launch_browser = true
      expect(Launchy).to receive(:open).with(a_string_matching(%r{\Afile://.*/sms\.html\z}))

      message = SmsOpener.deliver(
        to: "+15552223333",
        from: "+15559998888",
        body: "Hello from SmsOpener.deliver! Your OTP is 654321"
      )

      expect(message).to be_a(SmsOpener::Message)
      expect(message.otp_code).to eq("654321")
      expect(File.exist?(message.filepath)).to be(true)
      expect(SmsOpener.messages.size).to eq(1)
    end

    it "does not call Launchy.open when launch_browser is false" do
      SmsOpener.configuration.launch_browser = false
      expect(Launchy).not_to receive(:open)

      SmsOpener.deliver(to: "+15552223333", body: "Silent capture")
      expect(SmsOpener.messages.size).to eq(1)
    end

    it "accepts a Hash or an object responding to #to and #body" do
      custom_struct = Struct.new(:to, :from, :body).new("+15554445555", "+15550001111", "Struct SMS")
      delivered = described_class.new(launch_browser: false).deliver!(custom_struct)

      expect(delivered.to).to eq(["+15554445555"])
      expect(delivered.body).to eq("Struct SMS")
    end

    it "raises InvalidOption when :to or :body is missing" do
      expect {
        SmsOpener.deliver(to: "+15551112222")
      }.to raise_error(SmsOpener::DeliveryMethod::InvalidOption)
    end
  end
end
