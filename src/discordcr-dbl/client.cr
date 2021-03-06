require "http/client"
require "json"

module Dbl
  class Client
    BASE = URI.parse("https://discordbots.org")

    def initialize(authorization_token : String, cache : Discord::Cache? = nil)
      @client = HTTP::Client.new(BASE)
      @cache = cache.as(Discord::Cache)

      @client.before_request do |req|
        req.headers["Authorization"] = authorization_token
        req.headers["content-type"] = "application/json"
      end
    end

    @handlers = [] of HTTP::Client::Response ->
    def on_post(&handler : HTTP::Client::Response ->)
      @handlers << handler
    end

    def get_bots(params : Hash(String, String)? = nil)
      res = @client.get("/api/bots?#{params ? to_query_params(params) : ""}")
      Array(Bot).from_json(handle_response(res), root: "results")
    end

    def get_bot(id)
      res = @client.get("/api/bots/#{id}")
      Bot.from_json(handle_response(res))
    end

    def get_bot_stats(id)
      res = @client.get("/api/bots/#{id}/stats")
      Stats.from_json(handle_response(res))
    end

    def start
      spawn {
        loop {
          sleep 1800

          @client.post("/api/bots/stats", body: {server_count: @cache.guilds.size}.to_json) do |res|
            @handlers.each(&.call(res))
          end
        }
      }
    end

    private def to_query_params(params : Hash(String, String))
      HTTP::Params.build do |form_builder|
        params.each do |key, value|
          form_builder.add(key, value)
        end
      end
    end

    private def handle_response(res : HTTP::Client::Response)
      if res.success?
        res.body
      else
        raise ClientException.new(res)
      end
    end
  end
end
