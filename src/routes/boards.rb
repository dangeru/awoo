############################################
# => boards.rb - Board Renderer
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2017
#


require 'mysql2'
require 'sanitize'

API = "/api/v2"

def query(con, stmt, *args)
  return con.prepare(stmt).execute(*args)
end

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
  ip = request.ip
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
  post = post.to_i
  query(con, "SELECT board FROM posts WHERE post_id = ?", post).each do |res|
    board = res["board"]
  end
  if board == nil then
    return [400, "Post not found"]
  end
  if not is_moderator(board, session) then
    return [403, "You do not moderate " + board]
  end
  query(con, "UPDATE posts SET is_locked = ? WHERE post_id = ?", bool, post)
  href = "/" + board + "/thread/" + post.to_s
  return redirect(href, 303);
end

def sticky_unsticky(id, setting, con, session)
  board = nil
  id = id.to_i
  query(con, "SELECT board FROM posts WHERE post_id = ?", id).each do |res|
    board = res["board"]
  end
  if is_moderator(board, session) then
    query(con, "UPDATE posts SET sticky = ? WHERE post_id = ?", setting, id)
    return redirect("/" + board + "/thread/" + id, 303)
  else
    return [403, "You have no janitor privileges."]
  end
end

def get_ban_info(ip, board, con)
  if ip == nil then # fix for connecting from 127.0.0.1 when not behind a reverse proxy
    return nil
  end
  query(con, "SELECT date_of_unban, reason FROM bans WHERE ip = ? AND board = ? AND date_of_unban > CURRENT_TIMESTAMP()", ip, board).each do |res|
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
  query(con, "SELECT COUNT(*) AS count FROM posts WHERE ip = ? AND UNIX_TIMESTAMP(date_posted) > ?", ip, Time.new.strftime('%s').to_i - config["period_length"]).each do |res|
    if res["count"] >= config["max_posts_per_period"] then
      result = true
    else
      result = false
    end
  end
  return result
end
def make_con()
  return Mysql2::Client.new(:host => "localhost", :username => "awoo", :password => "awoo", :database => "awoo")
end
def make_metadata_from_hash(res, session)
  is_op = res["parent"] == nil
  obj = {:post_id => res["post_id"], :board => res["board"], :is_op => is_op, :comment => res["content"], :date_posted => res["date_posted"].strftime('%s').to_i, :hash => Digest::SHA256.hexdigest(res[:ip])[0..5]}
  if is_moderator(res["board"], session) then
    obj[:ip] = res["ip"]
  end
  if res["janitor"] != nil then
    obj[:capcode] = res["janitor"]
  end
  if is_op
    obj[:title] = res["title"]
    obj[:last_bumped] = res["last_bumped"].strftime("%s").to_i;
    obj[:is_locked] = res["is_locked"] != 0
    obj[:number_of_replies] = res["number_of_replies"]
    obj[:sticky] = res["sticky"] != 0
  else
    obj[:parent] = res["parent"]
  end
  return obj;
end
def make_metadata(con, id, session, config)
  id = id.to_i.to_s;
  result = [400, "No results found"]
  query(con, "SELECT *, (SELECT COUNT(*) FROM posts WHERE parent = ?) + 1 AS number_of_replies FROM posts WHERE post_id = ?", id, id).each do |hash|
    result = make_metadata_from_hash(hash, session)
  end
  if config["boards"][result[:board]]["hidden"] and not session[:moderates] then
    return "You have no janitor permissions"
  end
  return result
end

def try_login(username, password, config, session, params)
  config["janitors"].each do |janitor|
    if janitor["username"] == username and janitor["password"] == password then
      session[:moderates] = janitor["boards"]
      session[:username] = username
      # used by the mobile app
      if params[:redirect]
        return redirect(params[:redirect], 303)
      end
      return JSON.dump(janitor["boards"])
    end
  end
  return [403, "Check your username and password"]
end

def get_board(board, params, session, config)
  results = []
  if config["boards"][board]["hidden"] and not session[:moderates] then
    return [403, "You have no janitor permissions"]
  end
  page = 0
  if params[:page] then page = params[:page].to_i end
  offset = page * 20;
  con = make_con()
  query(con, "SELECT *, COALESCE(parent, post_id) AS effective_parent, COUNT(*) AS number_of_replies FROM posts WHERE board = ? GROUP BY effective_parent ORDER BY (-1 * sticky), last_bumped DESC LIMIT 20 OFFSET #{offset.to_s};", board).each do |res|
    results.push(make_metadata_from_hash(res, session))
  end
  return results
end

def get_thread_replies(id, session, config)
  con = make_con()
  results = []
  id = id.to_i.to_s
  query(con, "SELECT * FROM posts WHERE COALESCE(parent, post_id) = ?", id).each do |res|
    results.push(make_metadata_from_hash(res, session));
  end
  # dirty fucking hack
  results[0][:number_of_replies] = results.length
  if config["boards"][results[0][:board]]["hidden"] and not session[:moderates] then
    return [403, "You have no janitor permissions"]
  end
  return results
end

def mobile_js()
  res = ""
  f = File.open(File.dirname(__FILE__) + "/../static/static/mobile.js", "r")
  f.each_line do |line|
    res += line;
  end
  f.close
  return res
end

def apply_word_filters(config, path, content)
  config["boards"][path]["word-filter"].each do |a, b| content = content.gsub(a, b) end
  return content
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
          # Route for making a new OP
          app.post "/post" do
            con = make_con()
            # OPs have a board, a title and a comment.
            board = params[:board]
            title = params[:title]
            content = params[:comment]
            # Also pull the IP address from the request and check if it looks like spam
            ip = get_ip(con, request, env);
            if looks_like_spam(con, ip, env, config) then
              return [403, "Flood detected, post discarded"]
            elsif title.length > 500 or content.length > 500 then
              return [400, "Post too long (over 500 characters)"]
            elsif config["boards"][board]["hidden"] and not session[:username]
              return [403, "You have no janitor permissions"]
            end
            title = apply_word_filters(config, board, title)
            content = apply_word_filters(config, board, content)
            # Check if the IP is banned
            banned = get_ban_info(ip, board, con)
            if banned then return banned end
            # Insert the new post into the database
            unless params[:capcode] and session[:username]
              query(con, "INSERT INTO posts (board, title, content, ip) VALUES (?, ?, ?, ?)", board, title, content, ip);
            else
              query(con, "INSERT INTO posts (board, title, content, ip, janitor) VALUES (?, ?, ?, ?, ?)", board, title, content, ip, session[:username]);
            end
            # Then get the ID of the just-inserted post and redirect the user to their new thread
            query(con, "SELECT LAST_INSERT_ID() AS id").each do |res|
              href = "/" + params[:board] + "/thread/" + res["id"].to_s
              redirect(href, 303);
            end
            # if there was no "most-recently created post" then we probably have a bigger issue than a failed post
            return "Error? idk"
          end
          # Route for replying to an OP
          app.post "/reply" do
            con = make_con()
            # replies have a board, a comment and a parent (the post they're responding to)
            board = params[:board]
            content = params[:content]
            content = apply_word_filters(config, board, content)
            parent = params[:parent].to_i
            if make_metadata(con, parent, session, config)[:number_of_replies] >= config["bump_limit"]
              return [400, "Bump limit reached"]
            end
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
            query(con, "SELECT is_locked FROM posts WHERE post_id = ?", parent).each do |res|
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
              query(con, "INSERT INTO posts (board, parent, content, ip, title) VALUES (?, ?, ?, ?, NULL)", board, parent, content, ip)
            else
              query(con, "INSERT INTO posts (board, parent, content, ip, title, janitor) VALUES (?, ?, ?, ?, NULL, ?)", board, parent, content, ip, session[:username])
            end
            # Mark the parent as bumped
            query(con, "UPDATE posts SET last_bumped = CURRENT_TIMESTAMP() WHERE post_id = ?", parent);
            # Redirect them back to the post they just replied to
            #href = "/" + params[:board] + "/thread/" + params[:parent]
            #redirect(href, 303);
            # Ok nevermind just return ok so the js xhr doesn't go off and request the entire thread again
            return [200, "OK"]
          end

          # Each board has a listing of the posts there (board.erb) and a listing of the replies to a give post (thread.erb)
          boards.each do |path|
            app.get "/" + path + "/?" do
              con = make_con()
              if not params[:page]
                offset = 0;
              else
                offset = params[:page].to_i * 20;
              end
              if config["boards"][path]["hidden"] and not session["username"] then
                return [403, "You have no janitor privileges"]
              end
              erb :board, :locals => {:path => path, :config => config, :con => con, :offset => offset, :banner => new_banner(path), :moderator => is_moderator(path, session)}
            end
            app.get "/" + path + "/thread/:id" do |id|
              con = make_con()
              if config["boards"][path]["hidden"] and not session["username"] then
                return [403, "You have no janitor privileges"]
              end
              erb :thread, :locals => {:config => config, :path => path, :id => id, :con => con, :banner => new_banner(path), :moderator => is_moderator(path, session)}
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
            con = make_con()
            board = nil;
            post_id = post_id.to_i
            parent = nil
            # First, figure out which board that post is on
            query(con, "SELECT board, parent FROM posts WHERE post_id = ?", post_id).each do |res|
              board = res["board"]
              parent = res["parent"]
            end
            # Then, check if the currently logged in user has permission to moderate that board
            if not is_moderator(board, session)
              return [403, "You are not logged in or you do not moderate " + board]
            end
            # Insert an IP note with the content of the deleted post
            query(con, "SELECT content, title, ip FROM posts WHERE post_id = ?", post_id).each do |res|
              content = "Post Deleted - "
              if res["title"] then
                content += "OP with title: " + res["title"] + " - and "
              end
              content += "comment: " + res["content"]
              query(con, "INSERT INTO ip_notes (ip, content) VALUES (?, ?)", res["ip"], content)
            end
            # Finally, delete the post
            query(con, "DELETE FROM posts WHERE post_id = ? OR parent = ?", post_id, post_id)
            if parent != nil then
              href = "/" + board + "/thread/" + parent.to_s
              redirect(href, 303);
            else
              return "Success, probably."
            end
          end

          # Legacy api, see https://github.com/naomiEve/dangeruAPI
          app.get "/api.php" do
            con = make_con()
            limit = params[:ln]
            if not limit
              limit = "10000"
            end
            if params[:type] == "thread"
              id = params[:thread].to_i
              result = {:meta => [], :replies => []}
              limit = (limit.to_i + 1).to_s
              query(con, "SELECT * FROM posts WHERE parent = ? OR post_id = ? LIMIT #{limit}", id, id).each do |res|
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
              board = params[:board]
              query(con, "SELECT post_id, title, board, COALESCE(parent, post_id) AS effective_parent, COUNT(*)-1 AS number_of_replies FROM posts WHERE board = ? GROUP BY effective_parent ORDER BY post_id LIMIT #{limit};", board).each do |res|
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
            puts username, password
            return try_login(username, password, config, session, params)
          end
          app.get "/mod_login_success" do
            erb :mod_login_success, :locals => {:session => session, :config => config}
          end
          # Logout action, logs the user out and redirects to the mod login page
          app.get "/logout" do
            session[:moderates] = nil
            session[:username] = nil
            redirect("/mod", 303);
          end
          # Gets all post by IP, and let's you ban it
          app.get "/ip/:addr" do |addr|
            if not session[:moderates] then
              return [403, "You have no janitor permissions"]
            end
            con = make_con()
            erb :ip_list, :locals => {:session => session, :addr => addr, :con => con}
          end

          # Either locks or unlocks the specified thread
          app.get "/lock/:post/?" do |post|
            con = make_con()
            return lock_or_unlock(post, true, con, session)
          end
          app.get "/unlock/:post/?" do |post|
            con = make_con()
            return lock_or_unlock(post, false, con, session)
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
            con = make_con()
            # We allow the move if the person moderates at least one board, no matter which boards
            prev_board = nil;
            query(con, "SELECT board FROM posts WHERE post_id = ?", id).each do |res|
              prev_board = res["board"]
            end
            if is_moderator(prev_board, session)
              id = post.to_i
              board = params[:board]
              query(con, "UPDATE posts SET board = ? WHERE post_id = ? OR parent = ?", board, id, id)
              href = "/" + board + "/thread/" + id
              redirect href
            else
              return [403, "You have no janitor privileges."]
            end
          end

          # Leave notes on an ip address
          app.post "/ip_note/:addr" do |addr|
            con = make_con()
            if session[:moderates] == nil then
              return [403, "You have no janitor privileges"]
            end
            content = params[:content]
            query(con, "INSERT INTO ip_notes (ip, content) VALUES (?, ?)", addr, content)
            #return redirect("/ip/" + addr, 303)
            return [200, "OK"]
          end

          # Sticky / Unsticky posts
          app.get "/sticky/:id/?" do |post_id|
            con = make_con()
            sticky_unsticky(post_id, "TRUE", con, session)
          end
          app.get "/unsticky/:id/?" do |post_id|
            con = make_con()
            sticky_unsticky(post_id, "FALSE", con, session)
          end

          # Ban / Unban an IP
          app.post "/ban/:ip" do |author_ip|
            con = make_con()
            if is_moderator(params[:board], session) then
              ip = author_ip
              board = params[:board]
              old_date = params[:date].split('/')
              date = old_date[2] + "-" + old_date[0] + "-" + old_date[1] + " 00:00:00"
              reason = params[:reason]
              query(con, "INSERT INTO bans (ip, board, date_of_unban, reason) VALUES (?, ?, ?, ?)", ip, board, date, reason);
              redirect "/ip/#{ip}"
            else
              return [403, "You have no janitor privileges"]
            end
          end
          app.post "/unban/:ip" do |author_ip|
            con = make_con()
            if is_moderator(params[:board], session) then
              ip = author_ip
              board = params[:board]
              query(con, "DELETE FROM bans WHERE ip = ? AND board = ?", ip, board)
              redirect "/ip/#{ip}"
            else
              return [403, "You have no janitor privileges"]
            end
          end
          app.get API + "/boards" do
            JSON.dump(config["boards"].select do |key, value| session[:username] or not value["hidden"] end.map do |key, value| key end)
          end
          app.get API + "/board/:board" do |board|
            return JSON.dump(get_board(board, params, session, config))
          end
          app.get API + "/thread/:id/metadata" do |id|
            id = id.to_i.to_s
            return JSON.dump(make_metadata(make_con(), id, session, config))
          end
          app.get API + "/thread/:id/replies" do |id|
            id = id.to_i.to_s
            return JSON.dump(get_thread_replies(id, session, config))
          end
        end
      end
    end
  end
end
