# encoding: UTF-8
require 'rubygems'
require 'grape'
require 'gaston'
require 'sequel'
require 'sequel/extensions/pagination'

# Gaston
Gaston.configure do |gaston|
  gaston.env = ENV['RACK_ENV']
  gaston.files = Dir["config/gaston/**/*.yml"]
end

# Sequel
DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://quotes.db')

unless DB.table_exists?(:quotes)
  DB.create_table :quotes do
    primary_key :id
    String :topic
    String :body, null: false
  end
end

Sequel::Model.plugin :json_serializer
class Quote < Sequel::Model(:quotes)
  include Sequel::Dataset::Pagination
end

# Grape
module Cotedeporc
  class API < Grape::API
    error_format :json
    format :json
    default_format :json

    version 'v1', using: :header

    if Gaston.respond_to?(:http_digest) && Gaston.http_digest
      http_digest({realm: 'Quotes Api', opaque: 'secret'}) do |username|
        Gaston.http_digest[username]
      end
    end

    resource :quotes do
      get '/' do
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 10).to_i
        @quotes = Quote.paginate(page, per_page)
        @quotes = @quotes.filter(topic: params[:topic]) if params[:topic]
        if params[:body] && params[:body].size > 2
          @quotes = @quotes.filter(:body.like("%#{params[:body]}%"))
        end
        {
          page: @quotes.current_page,
          page_count: @quotes.page_count,
          total_entries_count: @quotes.pagination_record_count,
          entries: @quotes
        }
      end

      get '/:id' do
        @quote = Quote.first(id: params[:id])
        if @quote
          @quote
        else
          error!({error: 'not found'}, 404)
        end
      end

      put '/:id' do
        @quote = Quote.filter(id: params[:id]).first
        @quote.set_fields(params[:quote], [:topic, :body])
        if @quote.save
          @quote
        else
          error!({error: "unexpected error", detail: @quote.errors}, 500)
        end
      end

      post '/' do
        Quote.create(params[:quote])
      end
    end

  end
end
