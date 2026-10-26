# SmsOpener

Preview SMS and MMS messages in the browser instead of sending them in Ruby and Rails development environments.

Inspired by [`letter_opener`](https://github.com/ryanb/letter_opener) and [`letter_opener_web`](https://github.com/fgrehm/letter_opener_web), **`sms_opener`** provides:

1. **Automatic Browser Previews (via [`launchy`](https://github.com/copiousfreetime/launchy))**: Opens a mobile phone preview of every outgoing text message in your default browser as soon as it is sent.
2. **Mountable Rails Engine Web Inbox (`SmsOpener::Engine`)**: Browse, search, inspect, send test texts, and clear captured SMS/MMS messages at `/sms_opener`.
3. **Zero-Config `twilio-ruby` Interception**: Automatically intercepts `Twilio::REST::Client#messages.create` in development without making network requests or requiring real Twilio credentials.
4. **Direct Ruby API & Delivery Adapter**: Call `SmsOpener.deliver(to:, from:, body:)` or `SmsOpener::DeliveryMethod.new.deliver!(...)` from any custom SMS service object or adapter.
5. **Developer Conveniences**:
   - **1-Click OTP Detection**: Automatically extracts 4–8 digit verification/2FA codes with a one-click copy button.
   - **Clickable Magic Links**: Automatically extracts and links URLs inside SMS bodies.
   - **Segment & Encoding Inspector**: Calculates `GSM-7` vs `UCS-2` encoding, character count, and multi-segment boundaries (`160`/`153` vs `70`/`67`).

---

## Installation

Add `sms_opener` to your `Gemfile` under the `:development` group:

```ruby
group :development do
  gem "sms_opener"
end
```

Then run:

```bash
bundle install
```

---

## Usage

### 1. Automatic `twilio-ruby` Interception

If your application uses `twilio-ruby`, `sms_opener` automatically hooks into `Twilio::REST::Api::V2010::AccountContext::MessageList#create`.

```ruby
client = Twilio::REST::Client.new(ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"])

message = client.messages.create(
  to: "+15558675309",
  from: "+15550001234",
  body: "Your verification code is 849201"
)

message.sid    # => "SM..."
message.status # => "queued"
```

Instead of hitting Twilio's API, `sms_opener` saves the message to `tmp/sms_opener/`, opens the mobile preview in your browser, and returns a `Twilio::REST::Api::V2010::AccountContext::MessageInstance`.

### 2. Direct Ruby API (Custom SMS Services / Adapters)

If you use another SMS provider or a custom service object in your app, call `SmsOpener.deliver`:

```ruby
SmsOpener.deliver(
  to: "+15558675309",
  from: "+15550001234",
  body: "Sign in to your account: https://localhost:3000/magic?token=abc123",
  media_urls: ["https://example.com/receipt.png"], # optional MMS attachments
  provider: "custom_sms"                           # optional provider label
)
```

Or use `SmsOpener::DeliveryMethod` as a pluggable adapter:

```ruby
delivery = SmsOpener::DeliveryMethod.new(launch_browser: true)
delivery.deliver!(to: "+15558675309", from: "+15550001234", body: "Hello world!")
```

### 3. Mountable Rails Web Inbox (`SmsOpener::Engine`)

To browse all captured texts in a web UI (and optionally disable automatic browser tab popups), mount `SmsOpener::Engine` in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  if Rails.env.development?
    mount SmsOpener::Engine, at: "/sms_opener"
  end
end
```

Visit `http://localhost:3000/sms_opener` to:
- View all captured SMS/MMS messages in a split-pane inbox
- Copy detected 2FA/OTP codes with one click
- Search messages by phone number, body, or OTP code
- Send test SMS messages right from the browser
- Query `/sms_opener/messages.json` in development or system tests

---

## Configuration

Configure `sms_opener` in `config/environments/development.rb` or an initializer (`config/initializers/sms_opener.rb`):

```ruby
SmsOpener.configure do |config|
  # Directory where captured SMS files are stored (default: Rails.root.join("tmp", "sms_opener"))
  config.location = Rails.root.join("tmp", "sms_opener")

  # Open each SMS in the browser via Launchy when sent (default: true)
  # Set to false if you prefer checking the /sms_opener web inbox manually
  config.launch_browser = true

  # Automatically intercept twilio-ruby client.messages.create (default: true)
  config.intercept_twilio = true

  # Fallback sender number when `from:` is omitted (default: "+15550000000")
  config.default_from = "+15550000000"

  # Optional URI scheme override for Launchy (e.g., "file")
  config.file_uri_scheme = nil
end
```

Or via Rails environment configuration in `config/environments/development.rb`:

```ruby
Rails.application.configure do
  config.sms_opener.launch_browser = true
  config.sms_opener.intercept_twilio = true
end
```

---

## Inspecting Captured Messages in Console or Tests

```ruby
SmsOpener.messages           # => Array of SmsOpener::Message (newest first)
last_sms = SmsOpener.messages.first
last_sms.to                  # => ["+15558675309"]
last_sms.from                # => "+15550001234"
last_sms.body                # => "Your verification code is 849201"
last_sms.otp_code            # => "849201"
last_sms.urls                # => []
last_sms.encoding            # => "GSM-7"
last_sms.segments            # => 1

SmsOpener.clear!             # Deletes all stored messages
```

---

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
