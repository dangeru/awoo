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
  if session[:moderates].include? "all" then
      return true
  end
  return session[:moderates].include? board
end

# Updates the locked state of the given post to `bool`, where `bool` can either be true or false
# used in the /lock and /unlock routes
def lock_or_unlock(post, bool, con, session, config)
  board = nil
  post = post.to_i
  query(con, "SELECT board FROM posts WHERE post_id = ?", post).each do |res|
    board = res["board"]
  end
  if board == nil then
    return [400, "Post not found"]
  end
  if not is_moderator(board, session) or not has_permission(session, config, "lock") then
    return [403, "You do not moderate " + board]
  end
  query(con, "UPDATE posts SET is_locked = ? WHERE post_id = ?", bool, post)
  href = "/" + board + "/thread/" + post.to_s
  return redirect(href, 303);
end

# Stickies or unstickies a post, where `setting` can be true or false or a number indicating the stickyness
# used in /unsticky and both /sticky routes
def sticky_unsticky(id, setting, con, session, config)
  board = nil
  id = id.to_i
  query(con, "SELECT board FROM posts WHERE post_id = ?", id).each do |res|
    board = res["board"]
  end
  if is_moderator(board, session) and has_permission(session, config, "sticky") then
    content = "Changed stickyness on post /" + board + "/thread/" + id.to_s + " to new value " + setting.to_s
    query(con, "INSERT INTO ip_notes (ip, content, actor) VALUES (?, ?, ?)", "_meta", content, session[:username])
    query(con, "UPDATE posts SET sticky = ? WHERE post_id = ?", setting, id)
    return redirect("/" + board + "/thread/" + id.to_s, 303)
  else
    return [403, "You have no janitor privileges."]
  end
end

# Looks up whether the current user is banned, and if so, retrieves their ban information
def get_ban_info(ip, board, con)
  if ip == nil then # fix for connecting from 127.0.0.1 when not behind a reverse proxy
    return nil
  end
  query(con, "SELECT date_of_unban, reason, board FROM bans WHERE ip = ? AND (board = ? OR board = 'all') AND date_of_unban > CURRENT_TIMESTAMP()", ip, board).each do |res|
    return res
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

# Helper function for connecting to the database
def make_con()
  return Mysql2::Client.new(:host => "localhost", :username => "awoo", :password => "awoo", :database => "awoo")
end

# Makes an object for a thread's metadata from the given hash, used in the api's thread/:id/metadata route
# used in get_board which is used in the API's board/:board route and also views/board.erb
def make_metadata_from_hash(res, session, config)
  is_op = res["parent"] == nil
  # keys common to all posts (OPs and replies)
  obj = {:post_id => res["post_id"], :board => res["board"], :is_op => is_op, :comment => res["content"], :date_posted => res["date_posted"].strftime('%s').to_i}
  # Put ip in the object if the user has permission to see it
  if is_moderator(res["board"], session) and has_permission(session, config, "view_ips") then
    obj[:ip] = res["ip"]
  end
  # the janitor's capcode
  if res["janitor"] != nil then
    obj[:capcode] = res["janitor"]
  end
  # keys only applicable to OPs
  if is_op
    obj[:title] = res["title"]
    obj[:last_bumped] = res["last_bumped"].strftime("%s").to_i;
    obj[:is_locked] = res["is_locked"] != 0
    obj[:number_of_replies] = res["number_of_replies"]
    obj[:sticky] = res["sticky"] != 0
    # technically stickyness is zero for all unstickied posts, but only send it if the post is stickied anyways
    if res["sticky"] > 0 then
      obj[:stickyness] = res["sticky"]
    end
  else
    # if it's a reply, just list the parent
    obj[:parent] = res["parent"]
  end
  # the users tripcode
  if res["ip"].nil? then
    obj[:hash] = "FFFFFF";
  else
    if is_op then
      obj[:hash] = Digest::SHA256.hexdigest(res["ip"] + res["post_id"].to_s)[0..5]
    else
      obj[:hash] = Digest::SHA256.hexdigest(res["ip"] + res["parent"].to_s)[0..5]
    end
  end
  return obj;
end

# takes an id, pulls the relevant bits from the database and delegates the creation of the object to make_metadata_from_hash
def make_metadata(con, id, session, config)
  id = id.to_i.to_s;
  result = [400, "No results found"]
  query(con, "SELECT *, (SELECT COUNT(*) FROM posts WHERE parent = ?) + 1 AS number_of_replies FROM posts WHERE post_id = ?", id, id).each do |hash|
    result = make_metadata_from_hash(hash, session, config)
  end
  if config["boards"][result[:board]]["hidden"] and not session[:moderates] then
    return "You have no janitor permissions"
  end
  return result
end

# attempts to find a janitor with the matching username and password, or returns an error if there isn't one
def try_login(username, password, config, session, params)
  config["janitors"].each do |janitor|
    if janitor["username"] == username and janitor["password"] == password then
      session[:moderates] = janitor["boards"]
      session[:username] = username
      # used by the mobile app
      if params[:redirect]
        return redirect(params[:redirect], 303)
      end
      return erb :mod_login_success, :locals => {:session => session, :config => config}
    end
  end
  return [403, "Check your username and password"]
end

# gets the 20 threads for the requested board at the requested page (default zero, the first page)
# used in board.erb and the api's /board/:board route
def get_board(board, params, session, config)
  if config["boards"][board]["hidden"] and not session[:moderates] then
    return [404, erb(:notfound)]
  end
  con = make_con()
  # calculate which 20 posts to show
  page = 0
  if params[:page] then page = params[:page].to_i end
  offset = page * 20;
  # make a thread object for each returned row and return the list of all the thread objects
  results = []
  query(con, "SELECT *, COALESCE(parent, post_id) AS effective_parent, COUNT(*) AS number_of_replies FROM posts WHERE board = ? GROUP BY effective_parent ORDER BY (-1 * sticky), last_bumped DESC LIMIT 20 OFFSET #{offset.to_s};", board).each do |res|
    results.push(make_metadata_from_hash(res, session, config))
  end
  return results
end

def get_all(params, session, config)
  con = make_con()
  allowed_boards = config["boards"].select do |k, v| session[:moderates] or not v["hidden"] end.map do |k, v| k end
  allowed_boards = "(" + (allowed_boards.reduce([]) do |acc, k| acc.push("'" + con.escape(k) + "'") end.join ",") + ")"
  # calculate which 20 posts to show
  page = 0
  if params[:page] then page = params[:page].to_i end
  offset = page * 20;
  # make a thread object for each returned row and return the list of all the thread objects
  results = []
  query(con, "SELECT *, COALESCE(parent, post_id) AS effective_parent, COUNT(*) AS number_of_replies FROM posts WHERE board IN #{allowed_boards} GROUP BY effective_parent ORDER BY (-1 * sticky), last_bumped DESC LIMIT 20 OFFSET #{offset.to_s};").each do |res|
    results.push(make_metadata_from_hash(res, session, config))
  end
  return results
end

# Gets the replies to a given thread
def get_thread_replies(id, session, config)
  con = make_con()
  results = []
  id = id.to_i.to_s
  #
  query(con, "SELECT * FROM posts WHERE COALESCE(parent, post_id) = ?", id).each do |res|
    results.push(make_metadata_from_hash(res, session, config));
  end
  # dirty fucking hack
  results[0][:number_of_replies] = results.length
  if config["boards"][results[0][:board]]["hidden"] and not session[:moderates] then
    return [403, "You have no janitor permissions"]
  end
  return results
end

# read mobile.js into a string so the client on the phone doesn't have to make an extra request for it
# actually does speed up load time on mobile because the mobile page is gonna look like shit until it loads this javascript
def mobile_js()
  res = ""
  f = File.open(File.dirname(__FILE__) + "/../static/static/mobile.js", "r")
  f.each_line do |line|
    res += line;
  end
  f.close
  return res
end

# applies word filters to the given content, only applying them on a word break
def apply_word_filters(config, path, content)
  config["boards"][path]["word-filter"].each do |a, b| content = content.gsub(Regexp.new("\\b" + a + "\\b"), b) end
  return content
end

# wraps the given content for formatting in IP notes
# http://i.imgur.com/D63VXG0.png
def wrap(what, content)
  return "--- BEGIN " + what.upcase + " ---\n" + content + "\n--- END " + what.upcase + " ---\n"
end

# Gets if a janitor has the permission to perform an action
def has_permission(session, config, action)
  if not session[:username] then
    return false
  end

  config["janitors"].each do |mod|
    if mod["username"] == session[:username] then
      return config["ranks"][mod["rank"]] >= config["permissions"][action]
    end
  end

  return false
end

def allowed_capcodes(session, config)
  if not session[:username] then
    return []
  end
  rank = nil
  config["janitors"].each do |mod|
    if mod["username"] == session[:username] then
      rank = mod["rank"]
      break
    end
  end
  if rank.nil? then
    return []
  end
  res = []
  config["ranks"].each do |k, v|
    if v <= config["ranks"][rank] then
      res.push k
    end
  end
  return res
end

def does_thread_exist(id, board="")
  exists = false

  unless board.empty?
    con = make_con()
    query(con, "SELECT * FROM posts WHERE post_id=? AND board=? AND parent IS NULL", id, board).each do |res|
      exists = true
    end
  else
    con = make_con()
    query(con, "SELECT * FROM posts WHERE post_id=? AND parent IS NULL", id).each do |res|
      exists = true
    end
  end

  return exists
end
