############################################
# => boards.rb - Board Renderer
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2017
#

require 'mysql2'



module Sinatra
  module Awoo
    module Routing
      module Boards
        def self.registered(app)
          config_raw = File.read('config.json')
          config = JSON.parse(config_raw)
          hostname = config["hostname"]
          app.set :config, config
          boards = []
          config['boards'].each do |key, array|
            puts "Loading board " + config['boards'][key]['name'] + "..."
            boards << config['boards'][key]['name']
          end

          con = Mysql2::Client.new(:host => "localhost", :username => "awoo", :password => "awoo", :database => "test")
          app.post "/post" do
            board = con.escape(params[:board])
            title = con.escape(params[:title])
            content = con.escape(params[:comment])
            ip = con.escape("TODO")
            # todo check if the IP is banned
            # todo check for flooding/spam
            con.query("INSERT INTO posts (board, title, content, ip) VALUES ('#{board}', '#{title}', '#{content}', '#{ip}')");
            thing = "Error? idk"
            con.query("SELECT LAST_INSERT_ID() AS id").each do |res|
              thing = "<a href='/" + params[:board] + "/thread/" + res["id"].to_s + "'>Go</a>"
            end
            thing
          end
          app.post "/reply" do
            board = con.escape(params[:board])
            content = con.escape(params[:content])
            parent = con.escape(params[:parent].to_i.to_s)
            ip = con.escape("TODO")
            # todo check if the IP is banned
            # todo check for flooding/spam
            con.query("INSERT INTO posts (board, parent, content, ip) VALUES ('#{board}', '#{parent}', '#{content}', '#{ip}')")
            "<a href='/"+params[:board]+"/thread/"+params[:parent]+"'>Go</a>"
          end

          boards.each do |path|
            app.get "/" + path do
              erb :board, :locals => {:path => path, :con => con}
            end
            app.get "/" + path + "/thread/:id" do |id|
              erb :thread, :locals => {:path => path, :id => id, :con => con}
            end
          end

          # Legacy api, see https://github.com/naomiEve/dangeruAPI
          app.get "/api.php" do
            limit = params[:ln]
            if not limit
              limit = "10000"
            end
            if params[:type] == "thread"
              id = con.escape(params[:thread].to_i.to_s)
              result = {:meta => [], :replies => []}
              limit = con.escape((limit.to_i + 1).to_s)
              con.query("SELECT * FROM posts WHERE parent = #{id} OR post_id = #{id} LIMIT #{limit}").each do |res|
                if not res["parent"]
                  result[:meta] = [{
                    "title": res["title"],
                    "id": res["post_id"].to_s,
                    "url": "https://" + hostname + "/" + params[:board] + "/thread/" + params[:thread]
                  }]
                else
                  result[:replies].push({"post": res["content"]})
                end
              end
            else
              # type must be index
              result = {:board => [{
                :name => config["boards"][params[:board]]["name"],
                :url => "https://" + hostname + "/" + params[:board]
              }], :threads => []}
              limit = con.escape(limit.to_i.to_s)
              board = con.escape(params[:board]);
              con.query("SELECT post_id, title, board, COALESCE(parent, post_id) AS effective_parent, COUNT(*)-1 AS number_of_replies FROM posts WHERE board = '#{board}' GROUP BY effective_parent ORDER BY post_id LIMIT #{limit};").each do |res|
                result[:threads].push({
                  :id => res["post_id"],
                  :title => res["title"],
                  :url => "https://" + hostname + "/" + params["board"] + "/thread/" + res["post_id"].to_s
                })
              end
            end
            JSON.dump(result)
          end

        end
      end
    end
  end
end
