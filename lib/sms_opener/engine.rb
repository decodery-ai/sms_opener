# frozen_string_literal: true

require "rails/engine"

module SmsOpener
  class Engine < ::Rails::Engine
    isolate_namespace SmsOpener
  end
end
