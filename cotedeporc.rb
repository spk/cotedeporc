# frozen_string_literal: true
require 'hanami/api'
require 'sequel'
require 'sequel/extensions/migration'
require 'sequel/extensions/pagination'

module Cotedeporc
   def self.env
     ENV['RACK_ENV'] || 'development'
   end
end

# Sequel
DB = Sequel.connect(ENV['DATABASE_URL'] || "sqlite://quotes.#{Cotedeporc.env}.db")
DB.extension(:pagination)

Sequel::Migrator.run(DB, "migrations")

Sequel::Model.plugin :json_serializer
class Quote < Sequel::Model(:quotes)
  dataset_module do
    def confirmed
      where(state: 'confirmed')
    end

    def pending
      where(state: 'pending')
    end
  end
end

module Cotedeporc
  class API < Hanami::API
    NOT_FOUND = { error: 'not found' }.freeze

    class << self
      def paginate(collection, params, headers)
        page = Integer(params[:page] || 1)
        per_page = Integer(params[:per_page] || 10)
        collection.paginate(page, per_page).tap do |data|
          headers["X-Total"] = data.pagination_record_count.to_s
          headers["X-Total-Pages"] = data.page_count.to_s
          headers["X-Per-Page"] = per_page.to_s
          headers["X-Page"] = data.current_page.to_s
          headers["X-Next-Page"] = data.next_page.to_s
          headers["X-Prev-Page"] = data.prev_page.to_s
        end
      end

      def quotes_filters(quotes, params)
        quotes = quotes.where(topic: params[:topic]) if params[:topic]
        quotes = quotes.where(Sequel[:created_at] >= params[:start]) if params[:start]
        quotes = quotes.where(Sequel[:created_at] <= params[:end]) if params[:end]
        if params[:body] && params[:body].size > 2
          quotes = quotes.where(Sequel.ilike(:body, "%#{params[:body]}%"))
        end
        quotes
      end
    end

    scope :v1 do
      get '/quotes' do
        @quotes = Cotedeporc::API.paginate(Quote.confirmed, params, headers)
        @quotes = Cotedeporc::API.quotes_filters(@quotes, params)
        json({
          page: @quotes.current_page,
          page_count: @quotes.page_count,
          total_entries_count: @quotes.pagination_record_count,
          entries: @quotes
        })
      end

      post '/quotes' do
        json(Quote.create(params[:quote].merge(created_at: Time.now)))
      end

      scope :quotes do
        get '/pending' do
          @quotes = Cotedeporc::API.paginate(Quote.pending, params)
          @quotes = Cotedeporc::API.quotes_filters(@quotes, params)
          json({
            page: @quotes.current_page,
            page_count: @quotes.page_count,
            total_entries_count: @quotes.pagination_record_count,
            entries: @quotes
          })
        end

        get '/random' do
          @quotes = Quote.confirmed
          @quotes = Cotedeporc::API.quotes_filters(@quotes, params)
          offset = rand(@quotes.count)
          order = [:asc, :desc].sample
          @quote = @quotes.order(Sequel.send(order, :id)).limit(1, offset).first
          json(@quote)
        end

        get '/:id' do
          @quote = Quote.first(id: params[:id])
          if @quote
            json(@quote)
          else
            status(404)
            json(NOT_FOUND)
          end
        end

        put '/:id' do
          @quote = Quote.where(id: params[:id]).first
          unless @quote
            status(404)
            json(NOT_FOUND)
          else
            @quote.set_fields(params[:quote], [:topic, :body])
            if @quote.save
              json(@quote)
            else
              status(422)
              json({error: "unexpected error", detail: @quote.errors})
            end
          end
        end

        put '/:id/confirm' do
          @quote = Quote.where(id: params[:id]).first
          unless @quote
            status(404)
            json(NOT_FOUND)
          else
            @quote.set_fields({:state => 'confirmed'}, [:state])
            if @quote.save
              json(@quote)
            else
              status(422)
              json({error: "unexpected error", detail: @quote.errors})
            end
          end
        end

        delete '/:id' do
          @quote = Quote.first(id: params[:id])
          if @quote && @quote.delete
            json(@quote)
          else
            status(404)
            json(NOT_FOUND)
          end
        end
      end
    end
  end
end
