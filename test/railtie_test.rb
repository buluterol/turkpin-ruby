require "minitest/autorun"

begin
  require "rails"
rescue LoadError
  RAILS_MISSING = true
end

unless defined?(RAILS_MISSING)
  require "turkpin"
  require "turkpin/railtie"

  class RailtieTestApp < Rails::Application
    config.eager_load = false
    config.logger = Logger.new(nil)
    config.secret_key_base = "test" * 16
    config.turkpin.username = "dealer@example.com"
    config.turkpin.password = "secret"
    config.turkpin.test = true
  end
  RailtieTestApp.initialize!

  class RailtieTest < Minitest::Test
    def setup
      # other tests call Turkpin.reset!, so apply the Railtie initializer again
      Turkpin.reset!
      Turkpin::Railtie.initializers.find { |i| i.name == "turkpin.configure" }.run(RailtieTestApp)
    end

    def teardown
      Turkpin.reset!
    end

    def test_configures_client_from_rails_config
      assert_equal "dealer@example.com", Turkpin.configuration.username
      assert_equal Turkpin::TEST_URL, Turkpin.client.url
    end
  end
end
