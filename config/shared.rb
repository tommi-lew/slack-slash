ENV['BUNDLE_GEMFILE'] = File.expand_path('../Gemfile', File.dirname(__FILE__))

RACK_ENV ||= ENV['RACK_ENV'] || 'development'

require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?