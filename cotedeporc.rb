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
DB.extension(:pagination)

Sequel::Migrator.run(DB, "migrations")

Sequel::Model.plugin :json_serializer
class Quote < Sequel::Model(:quotes)
  dataset_module do
    def confirmed
      filter(state: 'confirmed')
    end

    def pending
      filter(state: 'pending')
    end
  end
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
      def quotes_filters(quotes)
        quotes = quotes.filter(topic: params[:topic]) if params[:topic]
        quotes = quotes.filter('created_at >= ?', params[:start]) if params[:start]
        quotes = quotes.filter('created_at <= ?', params[:end]) if params[:end]
        if params[:body] && params[:body].size > 2
          quotes = quotes.filter(Sequel.ilike(:body, "%#{params[:body]}%"))
        end
        quotes
      end
    end

    resource :quotes do
      get '/' do
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 10).to_i
        @quotes = Quote.confirmed.paginate(page, per_page)
        @quotes = quotes_filters(@quotes)
        {
          page: @quotes.current_page,
          page_count: @quotes.page_count,
          total_entries_count: @quotes.pagination_record_count,
          entries: @quotes
        }
      end

      get '/pending' do
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 10).to_i
        @quotes = Quote.pending.paginate(page, per_page)
        @quotes = quotes_filters(@quotes)
        {
          page: @quotes.current_page,
          page_count: @quotes.page_count,
          total_entries_count: @quotes.pagination_record_count,
          entries: @quotes
        }
      end

      get '/random' do
        @quotes = Quote.confirmed
        @quotes = quotes_filters(@quotes)
        offset = rand(@quotes.count)
        order = [:asc, :desc].sample
        @quote = @quotes.order(Sequel.send(order, :id)).limit(1, offset).first
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

      put '/:id/confirm' do
        @quote = Quote.filter(id: params[:id]).first
        @quote.set_fields({:state => 'confirmed'}, [:state])
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
