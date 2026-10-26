# frozen_string_literal: true

require "spec_helper"
require "action_controller/railtie"
require "rack/test"
require "sms_opener/railtie"
require "sms_opener/engine"

class TestRailsApp < Rails::Application
  config.root = File.expand_path("..", __dir__)
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "test_secret_key_base_for_sms_opener_engine_spec_1234567890"
  config.hosts.clear if config.respond_to?(:hosts)
end

TestRailsApp.initialize! unless TestRailsApp.initialized?

TestRailsApp.routes.draw do
  mount SmsOpener::Engine, at: "/sms_opener"
end

RSpec.describe SmsOpener::Engine do
  include Rack::Test::Methods

  def app
    TestRailsApp
  end

  it "renders the empty state when no messages exist" do
    get "/sms_opener"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("No SMS messages captured yet")
  end

  it "lists captured messages and displays OTP codes in the web inbox" do
    msg = SmsOpener.deliver(
      to: "+15557778888",
      from: "+15550001111",
      body: "Your login code is 902104"
    )

    get "/sms_opener"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("+15557778888")
    expect(last_response.body).to include("OTP: 902104")

    get "/sms_opener/messages/#{msg.id}"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("902104")
  end

  it "supports JSON format for listing and inspecting messages" do
    msg = SmsOpener.deliver(to: "+15553334444", body: "Confirmation code: 445566")

    get "/sms_opener/messages", {}, { "HTTP_ACCEPT" => "application/json" }
    expect(last_response.status).to eq(200)
    list = JSON.parse(last_response.body)
    expect(list.length).to eq(1)
    expect(list.first["id"]).to eq(msg.id)
    expect(list.first["otp_code"]).to eq("445566")

    get "/sms_opener/messages/#{msg.id}", {}, { "HTTP_ACCEPT" => "application/json" }
    expect(last_response.status).to eq(200)
    detail = JSON.parse(last_response.body)
    expect(detail["body"]).to eq("Confirmation code: 445566")
  end

  it "creates a test SMS via POST /sms_opener/messages" do
    post "/sms_opener/messages", {
      to: "+15556667777",
      from: "+15550009999",
      body: "Test from web UI: code 314159"
    }

    expect(last_response.status).to eq(302)
    expect(SmsOpener.messages.size).to eq(1)
    expect(SmsOpener.messages.first.otp_code).to eq("314159")
  end

  it "deletes an individual message and clears all messages" do
    msg1 = SmsOpener.deliver(to: "+15551110001", body: "First text")
    _msg2 = SmsOpener.deliver(to: "+15551110002", body: "Second text")
    expect(SmsOpener.messages.size).to eq(2)

    delete "/sms_opener/messages/#{msg1.id}"
    expect(last_response.status).to eq(302)
    expect(SmsOpener.messages.size).to eq(1)

    post "/sms_opener/messages/clear"
    expect(last_response.status).to eq(302)
    expect(SmsOpener.messages).to be_empty
  end
end
