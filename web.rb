require_relative File.join('config', 'shared.rb')

APP_RESERVATION_KEY = 'app_reservation'
APPS_FOR_RESERVATION_KEY = 'apps_for_reservation'

get '/' do
  'Slack Slash'
end

get '/ss' do
  if ENV['SLACK_TOKEN'] != params[:token]
    halt 404
  end

  if params[:text].nil?
    halt 'Y U NO COMMAND?'
  end

  username = params[:user_name]
  text_command = params[:text]

  command = text_command.split(' ')[0]
  app = text_command.split(' ')[1]
  admin_key = text_command.split(' ')[2]

  current_reserver_data = $redis.hget(APP_RESERVATION_KEY, app)
  current_reserver = if current_reserver_data
                       JSON.parse(current_reserver_data)['username']
                     else
                       nil
                     end

  if %w(use release).include?(command) &&
      !$redis.sismember(APPS_FOR_RESERVATION_KEY, app)
    halt 'App does not exist'
  end

  case command
    when 'use'
      reserve_app(current_reserver, username, app)
    when 'release'
      release_app(current_reserver, username, app)
    when 'frelease'
      frelease_app(username, app, admin_key)
    when 'available'
      available_apps
    when 'used'
      reserved_apps
    when 'add'
      add_app(app, admin_key)
    when 'del'
      delete_app(app, admin_key)
  end
end

def reserve_app(current_reserver, requester, app)
  if current_reserver.nil?
    $redis.hset(APP_RESERVATION_KEY, app, { username: requester, reserved_at: Date.today.to_s }.to_json)
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

def frelease_app(requester, app, admin_key)
  admin_key_check(admin_key, "Unable to release #{app}")

  $redis.hdel(APP_RESERVATION_KEY, app)
  halt "you have force released #{app}"
end

def available_apps
  if get_available_apps.size > 0
    halt "Available apps: \n #{get_available_apps.join("\n")}"
  else
    halt "No available apps, don't look at me like this."
  end
end

def reserved_apps
  apps = $redis.hgetall(APP_RESERVATION_KEY)
  no_of_apps = $redis.scard(APPS_FOR_RESERVATION_KEY)

  reserved_messages = apps.inject([]) do |result, (app, data)|
    data = JSON.parse(data)
    result << "#{app} - #{data['username']} since #{data['reserved_at']}"
  end

  halt "Used apps (#{apps.size}/#{no_of_apps}): \n" + reserved_messages.join("\n")
end

def get_available_apps
  all_apps = $redis.smembers(APPS_FOR_RESERVATION_KEY)
  all_apps.select{ |app| $redis.hget(APP_RESERVATION_KEY, app).nil? }
end

def get_reserved_apps
  all_apps = $redis.smembers(APPS_FOR_RESERVATION_KEY)
  all_apps.reject{ |app| $redis.hget(APP_RESERVATION_KEY, app).nil? }
end

def add_app(name, admin_key)
  admin_key_check(admin_key, 'Unable to add a new app')

  if $redis.sismember(APPS_FOR_RESERVATION_KEY, name)
    halt "#{name} already exist"
  else
    $redis.sadd(APPS_FOR_RESERVATION_KEY, name)
    halt "#{name} is added"
  end
end

def delete_app(name, admin_key)
  admin_key_check(admin_key, 'Unable to delete app')

  if $redis.sismember(APPS_FOR_RESERVATION_KEY, name)
    $redis.srem(APPS_FOR_RESERVATION_KEY, name)
    halt "#{name} is deleted"
  else
    halt "#{name} does not exist"
  end
end

def admin_key_check(admin_key, message = 'Unable to perform action')
  if admin_key != (ENV['ADMIN_KEY'] || 'admin_key')
    halt message
  end
end