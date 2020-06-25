# frozen_string_literal: true
require_relative 'spec_helper'

describe Cotedeporc::API do
  include Rack::Test::Methods

  def app
    Cotedeporc::API.new
  end

  describe Cotedeporc::API do
    before do
      DB[:quotes].truncate
    end

    describe "GET /quotes" do
      it "returns an empty array of quotes" do
        get "/v1/quotes"
        _(last_response.status).must_equal 200
        _(JSON.parse(last_response.body)['entries']).must_equal []
      end

      it 'can be filtered by start and end date' do
        Quote.create(
          topic: 'test', body: 'test',
          state: "confirmed", created_at: Time.new(2012)
        )
        Quote.create(
          topic: 'test', body: 'test',
          state: "confirmed", created_at: Time.new(2014)
        )
        get "/v1/quotes?start=2013-01-01&end=2015-01-01"
        _(JSON.parse(last_response.body)['entries'].size).must_equal 1
      end

      it 'have X-Page headers' do
        11.times {
          Quote.create(topic: 'test', body: 'test', state: "confirmed")
        }
        get "/v1/quotes"
        _(last_response.status).must_equal 200
        headers = last_response.headers
        _(headers['X-Total']).must_equal "11"
        _(headers['X-Total-Pages']).must_equal "2"
        _(headers['X-Per-Page']).must_equal "10"
        _(headers['X-Page']).must_equal "1"
        _(headers['X-Next-Page']).must_equal "2"
        _(headers['X-Prev-Page']).must_equal ""
        _(headers['Content-Type']).must_equal "application/json"
        get "/v1/quotes?page=2"
        headers = last_response.headers
        _(headers['X-Total']).must_equal "11"
        _(headers['X-Total-Pages']).must_equal "2"
        _(headers['X-Per-Page']).must_equal "10"
        _(headers['X-Page']).must_equal "2"
        _(headers['X-Next-Page']).must_equal ""
        _(headers['X-Prev-Page']).must_equal "1"
        _(headers['Content-Type']).must_equal "application/json"
      end
    end

    describe 'GET /v1/quotes/random' do
      it 'returns an random quote' do
        10.times {
          Quote.create(
            topic: 'test',
            body: 'test',
            state: %w{confirmed pending}.sample
          )
        }
        Quote.first.delete
        5.times {
          get "/v1/quotes/random"
          _(JSON.parse(last_response.body)['topic']).must_equal 'test'
        }
      end

      it 'returns a random filtered quote' do
        5.times do |i|
          Quote.create(topic: 'test', body: "test_#{i}", state: "confirmed")
        end
        get "/v1/quotes/random?body=test_1"
        _(JSON.parse(last_response.body)['body']).must_equal 'test_1'
      end
    end

    describe "POST /v1/quotes" do
      it "returns the created quote" do
        post "/v1/quotes?quote[topic]=youpi&quote[body]=youpi"
        _(last_response.status).must_equal 200
        _(JSON.parse(last_response.body)['body']).must_equal 'youpi'
      end
    end

    describe "DELETE /v1/quotes" do
      it "returns a 404" do
        delete "/v1/quotes/42"
        _(last_response.status).must_equal 404
        _(last_response.body).must_equal(Cotedeporc::API::NOT_FOUND.to_json)
      end

      it "returns the deleted quote" do
        quote = Quote.create(topic: 'test', body: 'test')
        delete "/v1/quotes/#{quote.id}"
        _(last_response.status).must_equal 200
        _(JSON.parse(last_response.body)['body']).must_equal 'test'
        _(proc { quote.reload }).must_raise Sequel::NoExistingObject
      end
    end

    describe "PUT /v1/quotes/:id" do
      it "returns a 404" do
        put "/v1/quotes/42"
        _(last_response.status).must_equal 404
        _(last_response.body).must_equal(Cotedeporc::API::NOT_FOUND.to_json)
      end

      it "returns the updated quotes" do
        quote = Quote.create(topic: 'test', body: 'test')
        put "/v1/quotes/#{quote.id}?quote[topic]=youpi&quote[body]=youpi"
        _(last_response.status).must_equal 200
        _(JSON.parse(last_response.body)['body']).must_equal 'youpi'
      end
    end

    describe "PUT /v1/quotes/:id/confirm" do
      it "returns a 404" do
        put "/v1/quotes/42/confirm"
        _(last_response.status).must_equal 404
        _(last_response.body).must_equal(Cotedeporc::API::NOT_FOUND.to_json)
      end

      it "returns the updated quotes" do
        quote = Quote.create(topic: 'test', body: 'test')
        put "/v1/quotes/#{quote.id}/confirm"
        _(last_response.status).must_equal 200
        _(JSON.parse(last_response.body)['state']).must_equal 'confirmed'
      end
    end

    describe "GET /v1/quotes/:id" do
      it "returns a 404" do
        get "/v1/quotes/42"
        _(last_response.status).must_equal 404
        _(last_response.body).must_equal(Cotedeporc::API::NOT_FOUND.to_json)
      end

      it "returns a status by id" do
        quote = Quote.create(topic: 'test', body: 'test')
        get "/v1/quotes/#{quote.id}"
        _(last_response.body).must_equal quote.to_json
      end
    end
  end
end
