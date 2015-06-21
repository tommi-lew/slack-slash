ENV['BUNDLE_GEMFILE'] = File.expand_path('../Gemfile', File.dirname(__FILE__))

RACK_ENV ||= ENV['RACK_ENV'] || 'development'

require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'redis'
require 'json'

# Redis
if RACK_ENV == 'production'
  uri = URI.parse(ENV['REDISTOGO_URL'])
  $redis = Redis.new(host: uri.host, port: uri.port, password: uri.password)
else
  $redis = Redis.new
end