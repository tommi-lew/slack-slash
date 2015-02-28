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
end
