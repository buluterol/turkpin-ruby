require "rails/railtie"

module Turkpin
  # Configures Turkpin.client from config.turkpin, then credentials (turkpin: username/password/test),
  # then TURKPIN_* environment variables.
  class Railtie < Rails::Railtie
    config.turkpin = ActiveSupport::OrderedOptions.new

    initializer "turkpin.configure" do |app|
      creds = app.respond_to?(:credentials) ? (app.credentials[:turkpin] || {}) : {}
      Turkpin.configure do |c|
        %i[username password test timeout base_url].each do |key|
          value = app.config.turkpin[key]
          value = creds[key] if value.nil?
          c.public_send("#{key}=", value) unless value.nil?
        end
      end
    end
  end
end
