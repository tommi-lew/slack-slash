require_relative File.join('config', 'shared.rb')

APP_RESERVATION_KEY = 'app_reservation'
APPS_FOR_RESERVATION_KEY = 'apps_for_reservation'

get '/' do
  'Slack Slash'
end

get '/ss' do
  if params[:text].nil?
    halt 'Y U NO COMMAND?'
  end

  username = params[:user_name]
  text_command = params[:text]

  command = text_command.split(' ')[0]
  app = text_command.split(' ')[1]

  current_reserver = $redis.hget(APP_RESERVATION_KEY, app)

  if %w(use release).include?(command) &&
      !$redis.sismember(APPS_FOR_RESERVATION_KEY, app)
    halt 'App does not exist'
  end

  case command
    when 'use'
      reserve_app(current_reserver, username, app)
    when 'release'
      release_app(current_reserver, username, app)
    when 'available'
      halt "Available apps: #{available_apps.join(', ')}"
  end
end

def reserve_app(current_reserver, requester, app)
  if current_reserver.nil?
    $redis.hset(APP_RESERVATION_KEY, app, requester)
    halt "#{app} is now yours, #{requester}"
  else
    halt "#{app} is reserved by #{current_reserver}"
  end
end

def release_app(current_reserver, requester, app)
  if current_reserver && current_reserver != requester
    halt "you cannot release #{app}, it is reserved by #{current_reserver}"
  else
    $redis.hdel(APP_RESERVATION_KEY, app)
    halt "you have released #{app}"
  end
end

def available_apps
  all_apps = $redis.smembers(APPS_FOR_RESERVATION_KEY)
  all_apps.select{ |app| $redis.hget(APP_RESERVATION_KEY, app).nil? }
end

def reserved_apps
  all_apps = $redis.smembers(APPS_FOR_RESERVATION_KEY)
  all_apps.reject{ |app| $redis.hget(APP_RESERVATION_KEY, app).nil? }
end