require 'spec_helper'

describe 'Slack Slash' do
  def app
    Sinatra::Application
  end

  def set_reservation(app, username)
    $redis.hset('app_reservation', app, username)
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
      $redis.hget('app_reservation', app)
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
      it 'sets username as hash value in redis and responds' do
        do_request user_name: 'bob', text: 'use euro'

        expect(get_reservation('euro')).to eq('bob')
        expect(last_response.body).to eq('euro is now yours, bob')
      end

      context 'staging app is already reserved' do
        it 'does not modify redis and responds' do
          set_reservation('euro', 'alice')

          do_request user_name: 'bob', text: 'use euro'

          expect(get_reservation('euro')).to eq('alice')
          expect(last_response.body).to eq('euro is reserved by alice')
        end
      end
    end

    describe 'release app' do
      it 'remove hash value in redis and responds' do
        set_reservation('euro', 'alice')

        do_request user_name: 'alice', text: 'release euro'

        expect(get_reservation('euro')).to be_nil
        expect(last_response.body).to eq('you have released euro')
      end

      context "attempts to release other's reservation" do
        it 'does not modify redis and responds' do
          set_reservation('euro', 'bob')

          do_request user_name: 'alice', text: 'release euro'

          expect(get_reservation('euro')).to eq('bob')
          expect(last_response.body).to eq('you cannot release euro, it is reserved by bob')
        end
      end
    end

    describe 'frelease app' do
      it 'remove hash value in redis and responds' do
        set_reservation('euro', 'alice')

        do_request user_name: 'alice', text: 'frelease euro fkey'

        expect(get_reservation('euro')).to be_nil
        expect(last_response.body).to eq('you have force released euro')
      end

      context 'missing fkey' do
        it 'does not modify redis and responds' do
          set_reservation('euro', 'bob')

          do_request user_name: 'alice', text: 'frelease euro'

          expect(get_reservation('euro')).to eq('bob')
          expect(last_response.body).to eq('unable to release euro')
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
        create_apps_for_reservation
        set_reservation('euro', 'alice')
        set_reservation('pound', 'bob')

        do_request text: 'used'

        expect(last_response.body).to match(/euro - alice/)
        expect(last_response.body).to match(/pound - bob/)
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
