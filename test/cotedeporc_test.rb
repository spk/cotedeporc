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
