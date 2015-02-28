RACK_ENV = 'test'

require_relative File.join('..', 'web.rb')
require 'rack/test'
require 'rspec'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  [:each].each do |x|
    config.before(x) do
      # Redis
      $redis.del('app_reservation')
    end
  end
end
