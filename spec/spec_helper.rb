RACK_ENV = 'test'

require_relative File.join('..', 'web.rb')
require 'rack/test'
require 'rspec'

RSpec.configure do |config|
  config.include Rack::Test::Methods
end

