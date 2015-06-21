require 'spec_helper'

describe 'Slack Slash' do
  def app
    Sinatra::Application
  end

  def set_reservation(app, username)
    $redis.hset('app_reservation', app, { username: username, reserved_at: Date.today.to_s }.to_json)
  end

  def create_apps_for_reservation
    $redis.sadd('apps_for_reservation', 'euro')
    $redis.sadd('apps_for_reservation', 'dollar')
    $redis.sadd('apps_for_reservation', 'pound')
  end

  describe 'GET /' do
    it "says 'Slack Slash'" do
      get '/'
      expect(last_response.body).to eq('Slack Slash')
    end
  end

  describe 'GET /ss' do
    ENV['SLACK_TOKEN'] = 'SLACKTOKEN'

    def do_request(opts = {})
      get '/ss', { token: 'SLACKTOKEN' }.merge(opts)
    end

    def get_reservation(app)
      data = $redis.hget('app_reservation', app)
      data ? JSON.parse(data) : nil
    end

    describe 'slack token' do
      context 'mismatch slack token' do
        it 'returns a 404' do
          do_request text: 'available', token: 'NOTTOKEN'
          expect(last_response.status).to eq(404)
        end
      end
    end

    describe 'without params' do
      it "says 'Y U NO COMMAND?'" do
        do_request
        expect(last_response.body).to eq('Y U NO COMMAND?')
      end
    end

    before do
      create_apps_for_reservation
    end

    describe 'reserve app' do
      it 'sets reservation data in redis and responds' do
        Timecop.freeze

        do_request user_name: 'bob', text: 'use euro'

        expect(get_reservation('euro')['username']).to eq('bob')
        expect(get_reservation('euro')['reserved_at']).to eq(Date.today.to_s)
        expect(last_response.body).to eq('euro is now yours, bob')
      end

      context 'staging app is already reserved' do
        it 'does not modify redis and responds' do
          set_reservation('euro', 'alice')

          do_request user_name: 'bob', text: 'use euro'

          expect(get_reservation('euro')['username']).to eq('alice')
          expect(last_response.body).to eq('euro is reserved by alice')
        end
      end
    end

    describe 'release app' do
      it 'remove reservation data in redis and responds' do
        set_reservation('euro', 'alice')

        do_request user_name: 'alice', text: 'release euro'

        expect(get_reservation('euro')).to be_nil
        expect(last_response.body).to eq('you have released euro')
      end

      context "attempts to release other's reservation" do
        it 'does not modify redis and responds' do
          set_reservation('euro', 'bob')

          do_request user_name: 'alice', text: 'release euro'

          expect(get_reservation('euro')['username']).to eq('bob')
          expect(last_response.body).to eq('you cannot release euro, it is reserved by bob')
        end
      end
    end

    describe 'frelease app' do
      it 'remove reservation data in redis and responds' do
        set_reservation('euro', 'alice')

        do_request user_name: 'alice', text: 'frelease euro admin_key'

        expect(get_reservation('euro')).to be_nil
        expect(last_response.body).to eq('you have force released euro')
      end

      context 'missing admin_key' do
        it 'does not modify redis and responds' do
          set_reservation('euro', 'bob')

          do_request user_name: 'alice', text: 'frelease euro'

          expect(get_reservation('euro')['username']).to eq('bob')
          expect(last_response.body).to eq('Unable to release euro')
        end
      end
    end

    describe 'enquires available apps' do
      it 'responds with available apps' do
        create_apps_for_reservation

        set_reservation('euro', 'alice')

        do_request text: 'available'

        response = last_response.body
        expect(response).to match(/dollar/)
        expect(response).to match(/pound/)
        expect(response).not_to match(/euro/)
      end

      context 'no available apps' do
        it 'responds with a message' do
          $redis.del('apps_for_reservation')
          $redis.sadd('apps_for_reservation', 'euro')
          set_reservation('euro', 'alice')

          do_request text: 'available'

          expect(last_response.body).to match(/No available apps/)
        end
      end
    end

    describe 'enquires reserved apps' do
      it 'responds with reserved apps' do
        Timecop.freeze

        create_apps_for_reservation
        set_reservation('euro', 'alice')
        set_reservation('pound', 'bob')

        do_request text: 'used'

        expect(
          last_response.body =~ Regexp.new(Regexp.quote("Used apps (2/3)"))
        ).not_to be_nil
        expect(last_response.body).to match(Regexp.quote("euro - alice since #{Date.today.to_s}"))
        expect(last_response.body).to match(Regexp.quote("pound - bob since #{Date.today.to_s}"))
        expect(last_response.body).not_to match(/dollar/)
      end
    end

    describe 'app does not exist' do
      it 'responds with an error message' do
        create_apps_for_reservation

        do_request text: 'use fish'

        expect(last_response.body).to eq('App does not exist')
      end
    end

    describe 'add new app' do
      before do
        create_apps_for_reservation
      end

      it 'adds new app into the redis set' do
        do_request text: 'add yen admin_key'

        expect($redis.scard(APPS_FOR_RESERVATION_KEY)).to eq(4)
        expect(last_response.body).to eq('yen is added')
      end

      context 'app exist' do
        it 'does nothing and responds' do
          do_request text: 'add euro admin_key'

          expect($redis.scard(APPS_FOR_RESERVATION_KEY)).to eq(3)
          expect(last_response.body).to eq('euro already exist')
        end
      end

      context 'missing admin key' do
        it 'does nothing and responds' do
          do_request text: 'add yen'

          expect($redis.scard(APPS_FOR_RESERVATION_KEY)).to eq(3)
          expect(last_response.body).to eq('Unable to add a new app')
        end
      end
    end

    describe 'delete app' do
      before do
        create_apps_for_reservation
      end

      it 'delete app from the redis set' do
        do_request text: 'del euro admin_key'

        expect($redis.smembers(APPS_FOR_RESERVATION_KEY).size).to eq(2)
        expect(last_response.body).to eq('euro is deleted')
      end

      context 'app does not exist' do
        it 'does nothing and responds' do
          do_request text: 'del yen admin_key'

          expect($redis.smembers(APPS_FOR_RESERVATION_KEY).size).to eq(3)
          expect(last_response.body).to eq('yen does not exist')
        end
      end

      context 'missing admin key' do
        it 'does nothing and responds' do
          do_request text: 'del yen'

          expect($redis.smembers(APPS_FOR_RESERVATION_KEY).size).to eq(3)
          expect(last_response.body).to eq('Unable to delete app')
        end
      end
    end
  end

  describe '#available_apps' do
    it 'returns available apps' do
      create_apps_for_reservation
      set_reservation('pound', 'alice')

      expect(get_available_apps).to match_array(['euro', 'dollar'])
    end
  end

  describe '#reserved_apps' do
    it 'returns reserved apps' do
      create_apps_for_reservation
      set_reservation('euro', 'alice')
      set_reservation('pound', 'alice')

      expect(get_reserved_apps).to match_array(['pound', 'euro'])
    end
  end
end
