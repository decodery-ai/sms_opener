# frozen_string_literal: true

require_relative "lib/sms_opener/version"

Gem::Specification.new do |spec|
  spec.name          = "sms_opener"
  spec.version       = SmsOpener::VERSION
  spec.authors       = ["Scott Stubblebine"]
  spec.email         = ["scott.c.stubblebine@gmail.com"]

  spec.summary       = "Preview SMS and MMS messages in the browser instead of sending them in Ruby/Rails development."
  spec.description   = "Inspired by letter_opener and letter_opener_web, sms_opener intercepts outgoing SMS/MMS messages " \
                       "(including Twilio and custom SMS adapters) in development, opens a mobile preview in your browser " \
                       "via Launchy, and provides a mountable Rails Engine web inbox."
  spec.homepage      = "https://github.com/stubblsc/sms_opener"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,lib}/**/*", "LICENSE.txt", "README.md", "Rakefile"]
  end
  spec.require_paths = ["lib"]

  # Runtime dependencies - use Launchy just like letter_opener to open local previews in the default browser
  spec.add_dependency "launchy", ">= 2.2", "< 4.0"

  # Development & test dependencies
  spec.add_development_dependency "actionpack", ">= 7.0", "< 9.0"
  spec.add_development_dependency "activesupport", ">= 7.0", "< 9.0"
  spec.add_development_dependency "rack-test", ">= 2.0", "< 3.0"
  spec.add_development_dependency "railties", ">= 7.0", "< 9.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "twilio-ruby", ">= 6.0", "< 8.0"
end
