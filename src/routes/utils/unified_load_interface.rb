############################################
# => unified_load_interface.rb - Helper functions for getting the data from posts in Awoo
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2018
#

require 'json'

# Updates the locked state of the given post to `bool`, where `bool` can either be true or false
# used in the /lock and /unlock routes
def lock_or_unlock(post, bool, con, session)
  board = nil
  post = post.to_i
  query(con, "SELECT board FROM posts WHERE post_id = ?", post).each do |res|
    board = res["board"]
  end
  if board == nil then
    return [400, "Post not found"]
  end
  if not is_moderator(board, session) or not has_permission(session, "lock") then
    return [403, "You do not moderate " + board]
  end
  query(con, "UPDATE posts SET is_locked = ? WHERE post_id = ?", bool, post)
  href = "/" + board + "/thread/" + post.to_s
  return redirect(href, 303);
end

# Stickies or unstickies a post, where `setting` can be true or false or a number indicating the stickyness
# used in /unsticky and both /sticky routes
def sticky_unsticky(id, setting, con, session)
  board = nil
  id = id.to_i
  query(con, "SELECT board FROM posts WHERE post_id = ?", id).each do |res|
    board = res["board"]
  end
  if is_moderator(board, session) and has_permission(session, "sticky") then
    content = "Changed stickyness on post /" + board + "/thread/" + id.to_s + " to new value " + setting.to_s
    query(con, "INSERT INTO ip_notes (ip, content, actor) VALUES (?, ?, ?)", "_meta", content, session[:username])
    query(con, "UPDATE posts SET sticky = ? WHERE post_id = ?", setting, id)
    return redirect("/" + board + "/thread/" + id.to_s, 303)
  else
    return [403, "You have no janitor privileges."]
  end
end

# Makes an object for a thread's metadata from the given hash, used in the api's thread/:id/metadata route
# used in get_board which is used in the API's board/:board route and also views/board.erb
def make_metadata_from_hash(res, session, override = false)
  is_op = res["title"] != nil
  # keys common to all posts (OPs and replies)
  obj = {:post_id => res["post_id"], :board => res["board"], :is_op => is_op, :comment => res["content"]}
  obj[:date_posted] = res["date_posted"] ? res["date_posted"].strftime('%s').to_i : 0;
  # Put ip in the object if the user has permission to see it
  if (is_moderator(res["board"], session) and has_permission(session, "view_ips")) or override then
    obj[:ip] = res["ip"]
  end
  # the janitor's capcode
  if res["janitor"] != nil then
    obj[:capcode] = res["janitor"]
  end
  # keys only applicable to OPs
  if is_op
    obj[:title] = res["title"]
    obj[:last_bumped] = res["last_bumped"] ? res["last_bumped"].strftime("%s").to_i : 0;
    obj[:is_locked] = res["is_locked"] != 0
    obj[:number_of_replies] = res["number_of_replies"]
    obj[:sticky] = res["sticky"] != 0 and not res["sticky"].nil?
    if res["sticky"].nil? then
      res["sticky"] = 0
    end
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
    obj[:hash] = make_hash(res["ip"], is_op ? res["post_id"] : res["parent"])
  end
  return obj;
end

# takes an id, pulls the relevant bits from the database and delegates the creation of the object to make_metadata_from_hash
def make_metadata(con, id, session)
  id = id.to_i.to_s;
  result = nil
  query(con, "SELECT *, (SELECT COUNT(*) FROM posts WHERE parent = ?) + 1 AS number_of_replies FROM posts WHERE post_id = ?", id, id).each do |hash|
    result = make_metadata_from_hash(hash, session)
  end
  return [400, "No results found"] if result.nil?
  return [400, "Board does not exist"] if not Config.get["boards"].include? result[:board]
  if Config.get["boards"][result[:board]]["hidden"] and not session[:moderates] then
    return "You have no janitor permissions"
  end
  return result
end

# gets the 20 threads for the requested board at the requested page (default zero, the first page)
# used in board.erb and the api's /board/:board route
def get_board(board, params, session, offset)
  if Config.get["boards"][board]["hidden"] and not session[:moderates] then
    return [404, erb(:notfound)]
  end
  con = make_con()
  # make a thread object for each returned row and return the list of all the thread objects
  results = []
  # Note that we COULD order by `(-1 * sticky), (SELECT MAX(p2.post_id) FROM posts p2 WHERE parent = post_id)` and we wouldn't need the extra `last_bumped` database column, but it would be more cpu/disk work on the database
  query(con, "SELECT *, COALESCE(parent, post_id) AS effective_parent, COUNT(*) AS number_of_replies FROM posts WHERE board = ? GROUP BY effective_parent ORDER BY (-1 * sticky), last_bumped DESC LIMIT 20 OFFSET #{offset.to_s};", board).each do |res|
    results.push(make_metadata_from_hash(res, session))
  end
  return results
end

def get_all(params, session, offset)
  con = make_con()
  allowed_boards = get_viewable_boards(session, Config.get["boards"].map { |k, v| k })
  allowed_boards = "(" + (allowed_boards.reduce([]) do |acc, k| acc.push("'" + con.escape(k) + "'") end.join ",") + ")"
  # make a thread object for each returned row and return the list of all the thread objects
  results = []
  query(con, "SELECT *, COALESCE(parent, post_id) AS effective_parent, COUNT(*) AS number_of_replies FROM posts WHERE board IN #{allowed_boards} GROUP BY effective_parent ORDER BY (-1 * sticky), last_bumped DESC LIMIT 20 OFFSET #{offset.to_s};").each do |res|
    results.push(make_metadata_from_hash(res, session))
  end
  return results
end

# Gets the replies to a given thread
def get_thread_replies(id, session, con = nil, override = false)
  con = make_con() if con.nil?
  results = []
  id = id.to_i.to_s
  #
  query(con, "SELECT * FROM posts WHERE COALESCE(parent, post_id) = ?", id).each do |res|
    results.push(make_metadata_from_hash(res, session, override));
  end
  # dirty fucking hack
  results[0][:number_of_replies] = results.length
  if not Config.get["boards"].has_key? results[0][:board] then
    return [400, "That board no longer exists"]
  end
  if Config.get["boards"][results[0][:board]]["hidden"] and not session[:moderates] and not override then
    return [403, "You have no janitor permissions"]
  end
  return results
end

def does_thread_exist(id, board="", con = nil)
  con = make_con() if con.nil?
  exists = false

  if not board.empty?
    query(con, "SELECT * FROM posts WHERE post_id=? AND board=? AND parent IS NULL", id, board).each do |res|
      exists = true
    end
  else
    query(con, "SELECT * FROM posts WHERE post_id=? AND parent IS NULL", id).each do |res|
      exists = true
    end
  end

  return exists
end

def does_archived_thread_exist(id, board = nil, con = nil)
  con = make_con if con.nil?
  exists = false
  if board then
    query(con, "SELECT * FROM archived_posts WHERE post_id=? AND board = ?", id, board).each do |res|
      exists = true
    end
  else
    query(con, "SELECT * FROM archived_posts WHERE post_id=?", id).each do |res|
      exists = true
    end
  end
  return exists
end

def get_archived_thread_replies(id)
  obj = nil
  File.open 'archive/' + id.to_s + '.json' do |contents|
    obj = JSON.parse contents.read, {:symbolize_names => true}
  end
  obj
end
def make_archived_hash(res, board = nil)
  hash = Hash.new
  hash[:post_id] = res["post_id"]
  hash[:title] = res["title"]
  hash[:board] = board
  hash[:number_of_replies] = res["number_of_posts"]
  hash[:board] = board ? board : res["board"]
  hash
end
def get_archived_board(con, board, offset)
  arr = []
  query(con, "SELECT post_id, title, number_of_posts FROM archived_posts WHERE board = ? ORDER BY post_id DESC LIMIT 20 OFFSET #{offset.to_s}", board).each do |res|
    arr.push make_archived_hash(res, board)
  end
  arr
end
def get_all_archived(con, offset)
  arr = []
  query(con, "SELECT post_id, title, board, number_of_posts FROM archived_posts ORDER BY post_id DESC LIMIT 20 OFFSET #{offset.to_s}").each do |res|
    arr.push make_archived_hash(res)
  end
  arr
end

def posts_count(con, board)
  count = 0
  if board == "all" then
    query(con, "SELECT COUNT(*) AS count FROM posts WHERE parent IS NULL").each do |res|
      count = res["count"]
    end
  else
    query(con, "SELECT COUNT(*) AS count FROM posts WHERE board = ? AND parent IS NULL", board).each do |res|
      count = res["count"]
    end
  end
  return count
end
def archived_posts_count(con, board)
  count = 0
  if board == "all" then
    query(con, "SELECT COUNT(*) AS count FROM archived_posts").each do |res|
      count = res["count"]
    end
  else
    query(con, "SELECT COUNT(*) AS count FROM archived_posts WHERE board = ?", board).each do |res|
      count = res["count"]
    end
  end
  return count
end
def make_hash(ip, post_id)
  return Digest::SHA256.hexdigest(ip + post_id.to_s)[0..5]
end
def get_popular(con, boards, session, offset)
  boards = get_viewable_boards(session, boards)
  boards = "(" + (boards.map do |b| "'" + con.escape(b) + "'" end).join(",") + ")"
  results = []
  query(con, "SELECT *, COALESCE(parent, post_id) AS effective_parent, COUNT(*) AS number_of_replies, (10000 * COUNT(*)) / (NOW() - date_posted) as rate FROM posts WHERE board IN #{boards} GROUP BY effective_parent ORDER BY rate DESC LIMIT 20 OFFSET #{offset.to_s};").each do |res|
    results.push(make_metadata_from_hash(res, session))
  end
  return results
end
def get_popular_count(con, boards, session)
  boards = get_viewable_boards(session, boards)
  boards = "(" + (boards.map do |b| "'" + con.escape(b) + "'" end).join(",") + ")"
  result = 0
  query(con, "SELECT COUNT(*) AS count FROM posts WHERE board IN #{boards};").each do |res|
    result = res["count"]
  end
  return result
end
def get_viewable_boards(session, boards)
  if session[:moderates] then
    return boards
  end
  return boards.select do |b| not Config.get["boards"][b]["hidden"] end
end
def get_notifier_replies(params, con, session)
  con = make_con()
  begin
    ids = JSON.parse(params[:list])
    hashes = JSON.parse(params[:hashes])
  rescue
    puts "error"
    return []
  end
  if ids.length == 0 then return [] end
  allowed_boards = get_viewable_boards(session, Config.get["boards"].map { |k, v| k })
  allowed_boards = "(" + (allowed_boards.reduce([]) do |acc, k| acc.push("'" + con.escape(k) + "'") end.join ",") + ")"
  where_clause = ids.map do |id| 'content like ?' end
  where_params = ids.map do |id| '%>>' + id.to_i.to_s + '%' end
  hashes.map do |h| where_clause << '(parent = ? and content like ?)' end
  hashes.map do |h| where_params += [h["op"], '%>>' + h["hash"] + '%'] end
  where_clause = where_clause.join(" OR ")
  puts where_clause
  results = []
  query(con, "SELECT post_id FROM posts WHERE board IN #{allowed_boards} AND (#{where_clause});", *where_params).each do |res|
    results.push(res["post_id"])
  end
  return results
end

