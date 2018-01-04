############################################
# => api.rb - API Router
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2018
#
require_relative 'utils'

module Sinatra
  module Awoo
    module Routing
      module API
      	API = "/api/v2"
        def self.registered(app)
          # NOTE(pref): since sinatra doesn't allow for a better way of doing this, we have to load the config file a sdfjhsdfjillion of times
          # NOTE(pref): also now we require one more rubygem only for this cool looking thing :^)))))
          config_raw = File.read('config.json')
          config = JSON.parse(config_raw)

          app.namespace API do
            get "/boards" do
              content_type 'application/json'
              JSON.dump(config["boards"].select do |key, value| session[:username] or not value["hidden"] end.map do |key, value| key end)
            end
            get "/board/:board/detail" do |board|
              content_type 'application/json'
              if config["boards"][board].nil? then
                return [404, JSON.dump({:error => 404, :message => "Board not found."})]
              end
              if config["boards"][board]["hidden"] and not session[:moderates] then
                return [404, JSON.dump({:error => 404, :message => "Board not found."})]
              end

              payload = {:name => config["boards"][board]["name"], :desc => config["boards"][board]["desc"], :rules => config["boards"][board]["rules"]}
              return JSON.dump(payload)
            end
            get "/board/:board" do |board|
              content_type 'application/json'
              if config["boards"][board].nil? then
                return [404, JSON.dump({:error => 404, :message => "Board not found."})]
              end
              if config["boards"][board]["hidden"] and not session[:moderates] then
                return [404, JSON.dump({:error => 404, :message => "Board not found."})]
              end

              if board == "all" then
                return JSON.dump(get_all(params, session, config))
              end
              return JSON.dump(get_board(board, params, session, config))
            end
            get "/thread/:id/metadata" do |id|
              content_type 'application/json'
              if does_thread_exist id then
                id = id.to_i.to_s
                return JSON.dump(make_metadata(make_con(), id, session, config))
              else
                return [404, JSON.dump({:error => 404, :message => "Thread not found."})]
              end
            end
            get "/thread/:id/replies" do |id|
              content_type 'application/json'
              if does_thread_exist id then
                id = id.to_i.to_s
                return JSON.dump(get_thread_replies(id, session, config))
              else
                return [404, JSON.dump({:error => 404, :message => "Thread not found."})]
              end
            end
          end
        end
      end
    end
  end
end
