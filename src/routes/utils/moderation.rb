############################################
# => moderation.rb - Helper functions for moderation
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2018
#

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
def looks_like_spam(con, ip, env)
  # if the user has never posted, the block in con.query.each won't be run, so by default it's not spam
  result = false
  query(con, "SELECT COUNT(*) AS count FROM posts WHERE ip = ? AND UNIX_TIMESTAMP(date_posted) > ?", ip, Time.new.strftime('%s').to_i - Config.get["period_length"]).each do |res|
    if res["count"] >= Config.get["max_posts_per_period"] then
      result = true
    else
      result = false
    end
  end
  return result
end

# attempts to find a janitor with the matching username and password, or returns an error if there isn't one
def try_login(username, password, session, params)
  Config.get["janitors"].each do |janitor|
    if janitor["username"] == username and janitor["password"] == password then
      session[:moderates] = janitor["boards"]
      session[:username] = username
      # used by the mobile app
      if params[:redirect]
        return redirect(params[:redirect], 303)
      end
      return erb :mod_login_success, :locals => {:session => session, :config => Config.get}
    end
  end
  return [403, "Check your username and password"]
end

# applies word filters to the given content, only applying them on a word break
def apply_word_filters(path, content)
  Config.get["boards"][path]["word-filter"].each do |a, b| content = content.gsub(Regexp.new("\\b" + a + "\\b"), b) end
  return content
end

# wraps the given content for formatting in IP notes
# http://i.imgur.com/D63VXG0.png
def wrap(what, content)
  return "--- BEGIN " + what.upcase + " ---\n" + content + "\n--- END " + what.upcase + " ---\n"
end

# Gets if a janitor has the permission to perform an action
def has_permission(session, action)
  if not session[:username] then
    return false
  end

  Config.get["janitors"].each do |mod|
    if mod["username"] == session[:username] then
      return Config.get["ranks"][mod["rank"]] >= Config.get["permissions"][action]
    end
  end

  return false
end

def allowed_capcodes(session)
  if not session[:username] then
    return []
  end
  rank = nil
  Config.get["janitors"].each do |mod|
    if mod["username"] == session[:username] then
      rank = mod["rank"]
      break
    end
  end
  if rank.nil? then
    return []
  end
  res = []
  Config.get["ranks"].each do |k, v|
    if v <= Config.get["ranks"][rank] then
      res.push k
    end
  end
  res.push "_hidden"
  return res
end

def delete_post(session, con, post_id)
  board = nil;
  post_id = post_id.to_i
  parent = nil
  ip = post_content = title = nil
  # First, figure out which board that post is on
  # TODO refactor to use the unified load interface
  query(con, "SELECT content, title, ip, board, parent FROM posts WHERE post_id = ?", post_id).each do |res|
    board = res["board"]
    parent = res["parent"]
    title = res["title"]
    ip = res["ip"]
    board = res["board"]
    post_content = res["content"]
  end
  if board.nil? then
    return [400, "Could not find a post with that ID"]
  end
  # Then, check if the currently logged in user has permission to moderate that board
  if not is_moderator(board, session) or not has_permission(session, "delete")
    return [403, "You are not logged in or you do not have permissions to perform this action on board " + board]
  end
  # Insert an IP note with the content of the deleted post
  content = ""
  if title then
    content += "Post deleted\n"
    content += "Board: " + board + "\n"
    content += wrap("title", title)
  else
    content += "Reply deleted\n"
    content += "Was a reply to /" + board + "/" + parent.to_s + "\n"
  end
  content += wrap("comment", post_content)
  query(con, "INSERT INTO ip_notes (ip, content, actor) VALUES (?, ?, ?)", ip, content, session[:username]) unless ip.nil?
  # Finally, delete the post
  query(con, "DELETE FROM posts WHERE post_id = ? OR parent = ?", post_id, post_id)
  if parent != nil then
    href = "/" + board + "/thread/" + parent.to_s
    return [303, href]
  else
    return [200, "Success, probably."]
  end
end
