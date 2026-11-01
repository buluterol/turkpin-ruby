module Turkpin
  # Shared settings for Turkpin.client. Defaults come from TURKPIN_USERNAME, TURKPIN_PASSWORD,
  # TURKPIN_TEST (1/true) and TURKPIN_TIMEOUT.
  class Configuration
    attr_accessor :username, :password, :test, :timeout, :base_url

    def initialize(env = ENV)
      @username = env["TURKPIN_USERNAME"]
      @password = env["TURKPIN_PASSWORD"]
      @test = %w[1 true yes on].include?(env["TURKPIN_TEST"].to_s.strip.downcase)
      @timeout = env["TURKPIN_TIMEOUT"] ? env["TURKPIN_TIMEOUT"].to_f : 30
      @base_url = nil
    end

    def to_h
      { username: username, password: password, test: test, timeout: timeout, base_url: base_url }
    end
  end

  MUTEX = Mutex.new
  private_constant :MUTEX

  class << self
    def configuration
      MUTEX.synchronize { @configuration ||= Configuration.new }
    end

    # Turkpin.configure { |c| c.username = "..."; c.password = "..."; c.test = true }
    def configure
      yield configuration
      MUTEX.synchronize { @client = nil }
      configuration
    end

    # Shared client built from the configuration.
    def client
      config = configuration
      MUTEX.synchronize { @client ||= Client.new(**config.to_h) }
    end

    def reset!
      MUTEX.synchronize do
        @configuration = nil
        @client = nil
      end
    end
  end
end
