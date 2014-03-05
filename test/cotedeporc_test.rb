# encoding: UTF-8
require_relative 'spec_helper'

describe Cotedeporc::API do
  include Rack::Test::Methods

  def app
    Cotedeporc::API
  end

  describe Cotedeporc::API do
    before do
      DB[:quotes].truncate
    end

    describe "GET /quotes" do
      it "returns an empty array of quotes" do
        get "/quotes"
        last_response.status.must_equal 200
        JSON.parse(last_response.body)['entries'].must_equal []
      end

      it 'can be filtered by start and end date' do
        Quote.create(topic: 'test', body: 'test', state: "confirmed", created_at: Time.new(2012))
        Quote.create(topic: 'test', body: 'test', state: "confirmed", created_at: Time.new(2014))
        get "/quotes?start=2013-01-01&end=2015-01-01"
        JSON.parse(last_response.body)['entries'].size.must_equal 1
      end
    end

    describe 'GET /quotes/random' do
      it 'returns an random quote' do
        10.times {
          Quote.create(topic: 'test', body: 'test', state: %w{confirmed pending}.sample)
        }
        Quote.first.delete
        5.times {
          get "/quotes/random"
          JSON.parse(last_response.body)['topic'].must_equal 'test'
        }
      end

      it 'returns a random filtered quote' do
        5.times do |i|
          Quote.create(topic: 'test', body: "test_#{i}", state: "confirmed")
        end
        get "/quotes/random?body=test_1"
        JSON.parse(last_response.body)['body'].must_equal 'test_1'
      end
    end

    describe "GET /quotes/:id" do
      it "returns a status by id" do
        quote = Quote.create(topic: 'test', body: 'test')
        get "/quotes/#{quote.id}"
        last_response.body.must_equal quote.to_json
      end
    end

  end
end
