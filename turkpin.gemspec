require_relative "lib/turkpin/version"

Gem::Specification.new do |s|
  s.name = "turkpin"
  s.version = Turkpin::VERSION
  s.summary = "Ruby client for the Turkpin dealer (bayi) API"
  s.description = "E-pin games, products, orders and balance through the Turkpin dealer API."
  s.authors = ["Erol Bulut"]
  s.homepage = "https://github.com/buluterol/turkpin-ruby"
  s.license = "MIT"
  s.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  s.required_ruby_version = ">= 2.6"
  s.add_dependency "rexml", ">= 3.1"
  s.add_dependency "bigdecimal", ">= 1.4"
end
