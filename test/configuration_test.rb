require "minitest/autorun"
require "turkpin"

class ConfigurationTest < Minitest::Test
  def teardown
    Turkpin.reset!
  end

  def test_reads_environment
    c = Turkpin::Configuration.new("TURKPIN_USERNAME" => "u", "TURKPIN_PASSWORD" => "p", "TURKPIN_TEST" => "true",
                                   "TURKPIN_TIMEOUT" => "5")
    assert_equal "u", c.username
    assert_equal true, c.test
    assert_equal 5.0, c.timeout
  end

  def test_configure_and_shared_client
    Turkpin.configure do |c|
      c.username = "dealer@example.com"
      c.password = "secret"
      c.test = true
    end
    assert_same Turkpin.client, Turkpin.client
    assert_equal Turkpin::TEST_URL, Turkpin.client.url

    Turkpin.configure { |c| c.test = false }
    assert_equal Turkpin::LIVE_URL, Turkpin.client.url
  end

  def test_missing_credentials
    Turkpin.configure do |c|
      c.username = nil
      c.password = nil
    end
    assert_raises(ArgumentError) { Turkpin.client }
  end
end
