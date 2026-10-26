# frozen_string_literal: true

require "spec_helper"
require "twilio-ruby"

RSpec.describe SmsOpener::Interceptors::TwilioInterceptor do
  before do
    described_class.install!
  end

  it "intercepts Twilio::REST::Client#messages.create and saves the message locally" do
    client = Twilio::REST::Client.new("AC11111111111111111111111111111111", "secret_token")

    response = client.messages.create(
      to: "+15558675309",
      from: "+15550001234",
      body: "Your Twilio verification code is 739201"
    )

    expect(response).to be_a(Twilio::REST::Api::V2010::AccountContext::MessageInstance)
    expect(response.sid).to match(/\ASM[0-9a-f]{32}\z/)
    expect(response.to).to eq("+15558675309")
    expect(response.from).to eq("+15550001234")
    expect(response.body).to eq("Your Twilio verification code is 739201")
    expect(response.status).to eq("queued")

    captured = SmsOpener.messages.first
    expect(captured).not_to be_nil
    expect(captured.provider).to eq("twilio")
    expect(captured.to).to eq(["+15558675309"])
    expect(captured.from).to eq("+15550001234")
    expect(captured.otp_code).to eq("739201")
    expect(captured.metadata["sid"]).to eq(response.sid)
  end

  it "uses MM prefix for MMS messages with media_url and supports messaging_service_sid" do
    client = Twilio::REST::Client.new(nil, nil)

    response = client.messages.create(
      to: "+15558675309",
      messaging_service_sid: "MG99999999999999999999999999999999",
      body: "Here is your receipt",
      media_url: ["https://example.com/receipt.png"]
    )

    expect(response.sid).to match(/\AMM[0-9a-f]{32}\z/)
    expect(response.num_media).to eq("1")

    captured = SmsOpener.messages.first
    expect(captured.from).to eq("MG99999999999999999999999999999999")
    expect(captured.media_urls).to eq(["https://example.com/receipt.png"])
    expect(captured.metadata["messaging_service_sid"]).to eq("MG99999999999999999999999999999999")
  end
end
