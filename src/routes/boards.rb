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
            "reply submitted"
          end

          boards.each do |path|
            app.get "/" + path do
              erb :board, :locals => {:path => path, :con => con}
            end
            app.get "/" + path + "/thread/:id" do |id|
              erb :thread, :locals => {:path => path, :id => id, :con => con}
            end
          end
        end
      end
    end
  end
end
