# encoding: UTF-8
require 'grape'
require 'gaston'
require 'sequel'
require 'sequel/extensions/migration'
require 'sequel/extensions/pagination'

module Cotedeporc
   def self.env
     ENV['RACK_ENV'] || 'development'
   end
end

# Gaston
Gaston.configure do |gaston|
  gaston.env = Cotedeporc.env
  gaston.files = Dir["config/gaston/**/*.yml"]
end

# Sequel
DB = Sequel.connect(ENV['DATABASE_URL'] || "sqlite://quotes.#{Cotedeporc.env}.db")

Sequel::Migrator.run(DB, "migrations")

Sequel::Model.plugin :json_serializer
class Quote < Sequel::Model(:quotes)
  include Sequel::Dataset::Pagination
end

# Grape
module Cotedeporc
  class API < Grape::API
    format :json
    default_format :json

    version 'v1', using: :header, vendor: 'cotedeporc'

    if Gaston.respond_to?(:http_digest) && Gaston.http_digest
      http_basic({realm: 'Quotes Api', opaque: 'secret'}) do |username|
        Gaston.http_digest[username]
      end
    end

    helpers do
      def quotes(page = 1, per_page = 10)
        @quotes = Quote.paginate(page, per_page)
        @quotes = @quotes.filter(topic: params[:topic]) if params[:topic]
        @quotes = @quotes.filter('created_at >= ?', params[:start]) if params[:start]
        @quotes = @quotes.filter('created_at <= ?', params[:end]) if params[:end]
        if params[:body] && params[:body].size > 2
          @quotes = @quotes.filter(:body.like("%#{params[:body]}%"))
        end
        @quotes
      end
    end

    resource :quotes do
      get '/' do
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 10).to_i
        @quotes = quotes(page, per_page)
        {
          page: @quotes.current_page,
          page_count: @quotes.page_count,
          total_entries_count: @quotes.pagination_record_count,
          entries: @quotes
        }
      end

      get '/random' do
        offset = rand(Quote.count)
        order = [:asc, :desc].sample
        @quote = Quote.order(Sequel.send(order, :id)).limit(1, offset).first
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
        Quote.create(params[:quote].merge(created_at: Time.now))
      end

      delete '/:id' do
        @quote = Quote.first(id: params[:id])
        if @quote && @quote.delete
          @quote
        else
          error!({error: "not found"}, 404)
        end
      end
    end

  end
end
