source 'https://rubygems.org'

ruby '2.2.3'

gem 'sinatra'
gem 'unicorn'
gem 'redis'

group :development do
  github 'sinatra/sinatra' do
    gem 'sinatra-contrib'
  end
  
  gem 'thin'
end

group :test do
  gem 'rack-test'
  gem 'rspec'
  gem 'timecop'
  gem 'codeclimate-test-reporter', require: nil
end
