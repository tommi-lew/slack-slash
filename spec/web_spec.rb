require 'spec_helper'

describe 'Slack Slash' do
  def app
    Sinatra::Application
  end

  describe 'GET /' do
    it "says 'Slack Slash'" do
      get '/'
      expect(last_response.body).to eq('Slack Slash')
    end
  end

  describe 'GET /ss' do
    def do_request(opts = {})
      get '/ss', opts
    end

    def set_reservation(app, username)
      $redis.hset('app_reservation', app, username)
    end

    def get_reservation(app)
      $redis.hget('app_reservation', app)
    end

    describe 'without params' do
      it "says 'Y U NO COMMAND?'" do
        get '/ss'
        expect(last_response.body).to eq('Y U NO COMMAND?')
      end
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
  end
end
