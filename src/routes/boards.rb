############################################
# => boards.rb - Board Renderer
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2017
#

require 'mysql2'
require 'sanitize'

def new_banner(board)
  if board.index("..") != nil
    return ""
  end
  dirs = Dir.entries(File.dirname(__FILE__) + "/../static/static/banners/" + board)
  fixed_dirs = []
  dirs.each do |x|
    if x[0] != "."
      fixed_dirs.push x
    end
  end
  "/static/banners/" + board + "/" + fixed_dirs.sample
end

def get_ip(con, request, env)
  ip = con.escape(request.ip)
  if ip == "127.0.0.1" 
    ip = env["HTTP_X_FORWARDED_FOR"]
  end
  return ip
end

def looks_like_spam(con, ip, env, config)
  result = false
  con.query("SELECT date_posted, ip FROM posts WHERE ip = '#{ip}' ORDER BY post_id DESC LIMIT 1").each do |res|
    if res["ip"] == ip and res["date_posted"] + config["min_seconds_between_post_per_ip"] > Time.new() then
      result = true
    else
      result = false
    end
  end
  return result
end

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
            ip = con.escape(request.ip)
            ip = get_ip(con, request, env);
            if looks_like_spam(con, ip, env, config) then
              return [403, "Flood detected, post discarded"]
            end
            # todo check if the IP is banned
            con.query("INSERT INTO posts (board, title, content, ip) VALUES ('#{board}', '#{title}', '#{content}', '#{ip}')");
            con.query("SELECT LAST_INSERT_ID() AS id").each do |res|
              href = "/" + params[:board] + "/thread/" + res["id"].to_s
              redirect(href, 303);
            end
            return "Error? idk"
          end
          app.post "/reply" do
            board = con.escape(params[:board])
            content = con.escape(params[:content])
            parent = con.escape(params[:parent].to_i.to_s)
            ip = get_ip(con, request, env);
            if looks_like_spam(con, ip, env, config) then
              return [403, "Flood detected, post discarded"]
            end
            # todo check if the IP is banned
            con.query("INSERT INTO posts (board, parent, content, ip) VALUES ('#{board}', '#{parent}', '#{content}', '#{ip}')")
            href = "/" + params[:board] + "/thread/" + params[:parent]
            redirect(href, 303);
          end

          boards.each do |path|
            app.get "/" + path do
              if not params[:page]
                offset = 0;
              else
                offset = params[:page].to_i * 20;
              end
              erb :board, :locals => {:path => path, :con => con, :offset => offset, :banner => new_banner(path)}
            end
            app.get "/" + path + "/thread/:id" do |id|
              erb :thread, :locals => {:path => path, :id => id, :con => con, :banner => new_banner(path)}
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

          app.get "/mod" do
            if session[:moderates] then
              return "You are already logged in and you moderate " + session[:moderates].join(", ")
            end
            erb :mod_login, :locals => {:session => session}
          end
          app.post "/mod" do
            username = params[:username]
            password = params[:password]
            config["janitors"].each do |janitor|
              if janitor["username"] == username and janitor["password"] == password then
                session[:moderates] = janitor["boards"]
                return "You are now logged in as " + username + ", you moderate " + janitor["boards"].join(", ")
              end
            end
            "Check your username and password"
          end
          app.get "/logout" do
            session[:moderates] = nil
          end
        end
      end
    end
  end
end
