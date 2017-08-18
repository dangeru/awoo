############################################
# => boards.rb - Board Renderer
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2017
#


require 'mysql2'
require 'sanitize'

# Attempts to pick a random banner for the given board
def new_banner(board)
  if board.index("..") != nil
    return ""
  end
  begin
    # this will throw an exception if the folder doesn't exist, hence the rescue
    dirs = Dir.entries(File.dirname(__FILE__) + "/../static/static/banners/" + board)
    # we have to remove "." and ".." from the list, but this will also remove all hidden files
    return "/static/banners/" + board + "/" + dirs.select {|f| !File.directory? f}.sample
  rescue
    # no banners for this board, just use the logo
    return "/static/logo.png"
  end
end

# this function tries to get the IP from the request, and if we're behind a reverse proxy it tries to get it from the environment variables
def get_ip(con, request, env)
  ip = con.escape(request.ip)
  if ip == "127.0.0.1"
    ip = env["HTTP_X_FORWARDED_FOR"]
  end
  return ip
end

# session[:moderates] is nil if the user isn't logged in, or a list of boards that the user moderates if they are logged in
# this function returns whether the user is a moderator of the given board
def is_moderator(board, session)
  if session[:moderates] == nil
    return false;
  end
  return session[:moderates].index(board) != nil
end
def lock_or_unlock(post, bool, con, session)
  board = nil
  escaped = con.escape(post.to_i.to_s)
  con.query("SELECT board FROM posts WHERE post_id = #{escaped}").each do |res|
    board = res["board"]
  end
  if board == nil then
    return [400, "Post not found"]
  end
  if not is_moderator(board, session) then
    return [403, "You do not moderate " + board]
  end
  con.query("UPDATE posts SET is_locked = #{con.escape(bool)} WHERE post_id = #{escaped}")
  href = "/" + board + "/thread/" + escaped
  return redirect(href, 303);
end

# This function fires off a request to the database to figure out when the last post by the given IP was
# and if it was in the last 30 seconds, it returns true (it is flooding), otherwise it returns false
# the 30 second figure is adjustable in the config.json
def looks_like_spam(con, ip, env, config)
  # if the user has never posted, the block in con.query.each won't be run, so by default it's not spam
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
          # Load up the config.json and read out some variables
          config_raw = File.read('config.json')
          config = JSON.parse(config_raw)
          hostname = config["hostname"]
          app.set :config, config
          # Load all the boards out of the config file
          boards = []
          config['boards'].each do |key, array|
            puts "Loading board " + config['boards'][key]['name'] + "..."
            boards << config['boards'][key]['name']
          end

          # Make a new mysql connection
          con = Mysql2::Client.new(:host => "localhost", :username => "awoo", :password => "awoo", :database => "awoo")
          # Route for making a new OP
          app.post "/post" do
            # OPs have a board, a title and a comment.
            board = con.escape(params[:board])
            title = con.escape(params[:title])
            content = con.escape(params[:comment])
            # Also pull the IP address from the request and check if it looks like spam
            ip = get_ip(con, request, env);
            if looks_like_spam(con, ip, env, config) then
              return [403, "Flood detected, post discarded"]
            end
            if title.length > 500 or content.length > 500 then
              return [400, "Post too long (over 500 characters)"]
            end
            # todo check if the IP is banned
            # Insert the new post into the database
            con.query("INSERT INTO posts (board, title, content, ip) VALUES ('#{board}', '#{title}', '#{content}', '#{ip}')");
            # Then get the ID of the just-inserted post and redirect the user to their new thread
            con.query("SELECT LAST_INSERT_ID() AS id").each do |res|
              href = "/" + params[:board] + "/thread/" + res["id"].to_s
              redirect(href, 303);
            end
            # if there was no "most-recently created post" then we probably have a bigger issue than a failed post
            return "Error? idk"
          end
          # Route for replying to an OP
          app.post "/reply" do
            # replies have a board, a comment and a parent (the post they're responding to)
            board = con.escape(params[:board])
            content = con.escape(params[:content])
            parent = con.escape(params[:parent].to_i.to_s)
            if content.length > 500 then
              return [400, "Reply too long (over 500 characters)"]
            end
            # Pull the IP address and check if it looks like spam
            ip = get_ip(con, request, env);
            if looks_like_spam(con, ip, env, config) then
              return [403, "Flood detected, post discarded"]
            end
            # todo check if the IP is banned
            closed = nil
            con.query("SELECT is_locked FROM posts WHERE post_id = #{parent}").each do |res|
              closed = res["is_locked"]
            end
            if closed == nil then
              return [400, "That thread doesn't exist"]
            elsif closed != 0 then
              return [400, "That thread has been closed"]
            end
            # Insert the new reply
            con.query("INSERT INTO posts (board, parent, content, ip, title) VALUES ('#{board}', '#{parent}', '#{content}', '#{ip}', NULL)")
            # Redirect them back to the post they just replied to
            href = "/" + params[:board] + "/thread/" + params[:parent]
            redirect(href, 303);
          end

          # Each board has a listing of the posts there (board.erb) and a listing of the replies to a give post (thread.erb)
          boards.each do |path|
            app.get "/" + path + "/?" do
              if not params[:page]
                offset = 0;
              else
                offset = params[:page].to_i * 20;
              end
              erb :board, :locals => {:path => path, :con => con, :offset => offset, :banner => new_banner(path), :moderator => is_moderator(path, session)}
            end
            app.get "/" + path + "/thread/:id" do |id|
              erb :thread, :locals => {:path => path, :id => id, :con => con, :banner => new_banner(path), :moderator => is_moderator(path, session)}
            end

            app.get "/" + path + "/rules/?" do
              erb :rules, :locals => {:rules => settings.config['boards'][path]['rules'], :moderator => is_moderator(path, session), :path => path, :banner => new_banner(path)}
            end
          end

          # Route for moderators to delete a post (and all of its replies, if it's an OP)
          app.get "/delete/:post_id" do |post_id|
            board = nil;
            escaped = con.escape(post_id.to_i.to_s)
            parent = nil
            # First, figure out which board that post is on
            con.query("SELECT board, parent FROM posts WHERE post_id = #{escaped}").each do |res|
              board = res["board"]
              parent = res["parent"]
            end
            # Then, check if the currently logged in user has permission to moderate that board
            if not is_moderator(board, session)
              return [403, "You are not logged in or you do not moderate " + board]
            end
            # Finally, delete the post
            con.query("DELETE FROM posts WHERE post_id = #{escaped} OR parent = #{escaped}")
            if parent != nil then
              href = "/" + board + "/thread/" + parent.to_s
              redirect(href, 303);
            else
              return "Success, probably."
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

          # Moderator log in page, (mod_login.erb)
          app.get "/mod" do
            if session[:moderates] then
              return "You are already logged in and you moderate " + session[:moderates].join(", ")
            end
            erb :mod_login, :locals => {:session => session}
          end
          # Moderator log in action, checks the username and password against the list of janitors and logs them in if it matches
          app.post "/mod" do
            username = params[:username]
            password = params[:password]
            config["janitors"].each do |janitor|
              if janitor["username"] == username and janitor["password"] == password then
                session[:moderates] = janitor["boards"]
                return "You are now logged in as " + username + ", you moderate " + janitor["boards"].join(", ") + '&nbsp;<a href="/logout">Log out</a>'
              end
            end
            "Check your username and password"
          end
          # Logout action, logs the user out and redirects to the mod login page
          app.get "/logout" do
            session[:moderates] = nil
            redirect("/mod", 303);
          end
          # Gets all post by IP, and let's you ban it
          app.get "/ip/:addr" do |addr|
            erb :ip_list, :locals => {:session => session, :addr => addr, :con => con}
          end

          # Either locks or unlocks the specified thread
          app.get "/lock/:post/?" do |post|
            return lock_or_unlock(post, "TRUE", con, session)
          end
          app.get "/unlock/:post/?" do |post|
            return lock_or_unlock(post, "FALSE", con, session)
          end

          # Moves thread from board to board
          app.get "/move/:post/?" do |post|
            if session[:moderates] then
              erb :move, :locals => {:post => post}
            else
              return [403, "You have no janitor priviledges."]
            end
          end
          app.post "/move/:post/?" do |post|
            if session[:moderates] then
              id = con.escape(post)
              board = con.escape(params[:board])
              con.query("UPDATE posts SET board = '#{board}' WHERE post_id = #{id} OR parent = #{id}")
              href = "/" + board + "/thread/" + id
              redirect href
            else
              return [403, "You have no janitor priviledges."]
            end
          end
        end
      end
    end
  end
end
