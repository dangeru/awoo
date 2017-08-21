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

def sticky_unsticky(id, setting, con, session)
  board = nil
  id = con.escape(id.to_i.to_s)
  con.query("SELECT board FROM posts WHERE post_id = #{id}").each do |res|
    board = res["board"]
  end
  if is_moderator(board, session) then
    id = con.escape(id)
    con.query("UPDATE posts SET sticky = #{setting} WHERE post_id = #{id}")
    return redirect("/" + board + "/thread/" + id, 303)
  else
    return [403, "You have no janitor privileges."]
  end
end

def get_ban_info(ip, board, con)
  if ip == nil then # fix for connecting from 127.0.0.1 when not behind a reverse proxy
    return nil
  end
  ip = con.escape(ip)
  board = con.escape(board)
  con.query("SELECT date_of_unban, reason FROM bans WHERE ip = '#{ip}' AND board = '#{board}' AND date_of_unban > CURRENT_TIMESTAMP()").each do |res|
    reason = Sanitize.clean(res["reason"])
    date_of_unban = Sanitize.clean(res["date_of_unban"])
    return [403, "You are banned. Reason given: #{reason}. Expiration: #{date_of_unban}"]
  end
  return nil
end

# This function fires off a request to the database to figure out how many posts this IP has made in the last
# 30 seconds, and if it was greater than or equal to 4, it returns true (it is flooding), otherwise it returns false
# the 30 second and 4 posts figures are adjustable in the config.json
def looks_like_spam(con, ip, env, config)
  # if the user has never posted, the block in con.query.each won't be run, so by default it's not spam
  result = false
  con.query("SELECT COUNT(*) AS count FROM posts WHERE ip = '#{ip}' AND UNIX_TIMESTAMP(date_posted) > #{Time.new.strftime('%s').to_i - config["period_length"]}").each do |res|
    if res["count"] >= config["max_posts_per_period"] then
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
            elsif title.length > 500 or content.length > 500 then
              return [400, "Post too long (over 500 characters)"]
            elsif config["boards"][board]["hidden"] and not session[:username]
              return [403, "You have no janitor permissions"]
            end
            # Check if the IP is banned
            banned = get_ban_info(ip, board, con)
            if banned then return banned end
            # Insert the new post into the database
            unless params[:capcode] and session[:username]
              con.query("INSERT INTO posts (board, title, content, ip) VALUES ('#{board}', '#{title}', '#{content}', '#{ip}')");
            else
              con.query("INSERT INTO posts (board, title, content, ip, janitor) VALUES ('#{board}', '#{title}', '#{content}', '#{ip}', '#{session[:username]}')");
            end
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
            # Check if the IP is banned
            banned = get_ban_info(ip, board, con)
            if banned then return banned end
            closed = nil
            con.query("SELECT is_locked FROM posts WHERE post_id = #{parent}").each do |res|
              closed = res["is_locked"]
            end
            if closed == nil then
              return [400, "That thread doesn't exist"]
            elsif closed != 0 then
              return [400, "That thread has been closed"]
            elsif config["boards"][board]["hidden"] and not session[:username]
              return [403, "You have no janitor permissions"]
            end
            # Insert the new reply
            unless params[:capcode] and session[:username]
              con.query("INSERT INTO posts (board, parent, content, ip, title) VALUES ('#{board}', '#{parent}', '#{content}', '#{ip}', NULL)")
            else
              con.query("INSERT INTO posts (board, parent, content, ip, title, janitor) VALUES ('#{board}', '#{parent}', '#{content}', '#{ip}', NULL, '#{session[:username]}')")
            end
            # Mark the parent as bumped
            con.query("UPDATE posts SET last_bumped = CURRENT_TIMESTAMP() WHERE post_id = '#{parent}'");
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
              if config["boards"][path]["hidden"] and not session["username"] then
                return [403, "You have no janitor privileges"]
              end
              erb :board, :locals => {:path => path, :con => con, :offset => offset, :banner => new_banner(path), :moderator => is_moderator(path, session)}
            end
            app.get "/" + path + "/thread/:id" do |id|
              if config["boards"][path]["hidden"] and not session["username"] then
                return [403, "You have no janitor privileges"]
              end
              erb :thread, :locals => {:path => path, :id => id, :con => con, :banner => new_banner(path), :moderator => is_moderator(path, session)}
            end

            # Rules & Editing rules
            app.get "/" + path + "/rules/?" do
              if config["boards"][path]["hidden"] and not session["username"] then
                return [403, "You have no janitor privileges"]
              end
              erb :rules, :locals => {:rules => settings.config['boards'][path]['rules'], :moderator => is_moderator(path, session), :path => path, :banner => new_banner(path)}
            end
            app.post "/" + path + "/rules/edit/?" do
              if is_moderator(path, session)
                settings.config['boards'][path]['rules'] = Sanitize.clean(params[:rules])
                File.open("config.json", "w") do |f|
                  f.write(JSON.pretty_generate(settings.config))
                end
                redirect "/" + path + "/rules"
              else
                return [403, "You have no janitor privileges."]
              end
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
            # Insert an IP note with the content of the deleted post
            con.query("SELECT content, title, ip FROM posts WHERE post_id = #{escaped}").each do |res|
              escaped_addr = con.escape(res["ip"])
              content = "Post Deleted - "
              if res["title"] then
                content += "OP with title: " + res["title"] + " - and "
              end
              content += "comment: " + res["content"]
              escaped_content = con.escape(content);
              con.query("INSERT INTO ip_notes (ip, content) VALUES ('#{escaped_addr}', '#{escaped_content}')")
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
              return "You are already logged in as "+Sanitize.clean(session[:username])+" and you moderate " + session[:moderates].join(", ") + '&nbsp;<a href="/logout">Log out</a>'
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
                session[:username] = username
                return "You are now logged in as " + username + ", you moderate " + janitor["boards"].join(", ") + '&nbsp;<a href="/logout">Log out</a>'
              end
            end
            [403, "Check your username and password"]
          end
          # Logout action, logs the user out and redirects to the mod login page
          app.get "/logout" do
            session[:moderates] = nil
            session[:username] = nil
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
              erb :move, :locals => {:post => post, :boards => boards}
            else
              return [403, "You have no janitor privileges."]
            end
          end
          app.post "/move/:post/?" do |post|
            # We allow the move if the person moderates at least one board, no matter which boards
            if session[:moderates] then
              id = con.escape(post.to_i.to_s)
              board = con.escape(params[:board])
              con.query("UPDATE posts SET board = '#{board}' WHERE post_id = #{id} OR parent = #{id}")
              href = "/" + board + "/thread/" + id
              redirect href
            else
              return [403, "You have no janitor privileges."]
            end
          end

          # Leave notes on an ip address
          app.post "/ip_note/:addr" do |addr|
            if session[:moderates] == nil then
              return [403, "You have no janitor privileges"]
            end
            addr = con.escape(addr)
            content = con.escape(params[:content])
            con.query("INSERT INTO ip_notes (ip, content) VALUES ('#{addr}', '#{content}')")
            return redirect("/ip/" + addr, 303)
          end

          # Sticky / Unsticky posts
          app.get "/sticky/:id/?" do |post_id|
            sticky_unsticky(post_id, "TRUE", con, session)
          end
          app.get "/unsticky/:id/?" do |post_id|
            sticky_unsticky(post_id, "FALSE", con, session)
          end

          # Ban / Unban an IP
          app.post "/ban/:ip" do |author_ip|
            if is_moderator(params[:board], session) then
              ip = con.escape(author_ip)
              board = con.escape(params[:board])
              old_date = con.escape(params[:date]).split('/')
              date = old_date[2] + "-" + old_date[0] + "-" + old_date[1] + " 00:00:00"
              reason = con.escape(params[:reason])
              con.query("INSERT INTO bans (ip, board, date_of_unban, reason) VALUES ('#{ip}', '#{board}', '#{date}', '#{reason}')");
              redirect "/ip/#{ip}"
            else
              return [403, "You have no janitor privileges"]
            end
          end
          app.post "/unban/:ip" do |author_ip|
            if is_moderator(params[:board], session) then
              ip = con.escape(author_ip)
              board = con.escape(params[:board])
              con.query("DELETE FROM bans WHERE ip = '#{ip}' AND board = '#{board}'")
              redirect "/ip/#{ip}"
            else
              return [403, "You have no janitor privileges"]
            end
          end
        end
      end
    end
  end
end
