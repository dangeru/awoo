############################################
# => search.rb - Helper functions for searching for posts
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2018
#

def get_search_results(params, con, offset, session)
  exclude = []
  exclude_args = []
  if not session[:username] then
    Config.get["boards"].to_a.each do |b|
      if b[1]["hidden"] then
        exclude << "board != ?"
        exclude_args << b[0]
      end
    end
  end
  exclude = exclude.join(" AND ")
  exclude = " AND " + exclude if not exclude.empty?
  restrict = ""
  restrict_args = []
  if params[:board_select] != "all" then
    restrict = "AND board = ?"
    restrict_args << params[:board_select]
  end
  where_clause = "title LIKE ? " + exclude + " " + restrict
  make_query = ->(where_clause, for_count) do
    cols = %w(post_id title board)
    #cols.map! do |c| c + " COLLATE utf8mb4_unicode_ci" end # This hack is only here because pref has a shit mysql server
    cols = cols.join ", "
    cols = "COUNT(*) AS count" if for_count
    limit = "LIMIT 20 OFFSET #{offset}"
    limit = "" if for_count
    query = "SELECT #{cols} FROM posts WHERE #{where_clause}"
    query += " UNION ALL "
    query += "SELECT #{cols} FROM archived_posts WHERE #{where_clause} #{limit}"
    query
  end
  first_query = make_query.call where_clause, false
  results = []
  args = ["%" + params[:search_text] + "%"]
  args += exclude_args
  args += restrict_args
  args += args
  #puts first_query, args.join(",")
  query(con, first_query, *args).each do |res|
    results << make_archived_hash(res)
  end
  if not results.empty?
    q = make_query.call where_clause, true
    count = 0
    query(con, q, *args).each do |res|
      count = res["count"]
    end
    return [results, count]
  end
  words = params[:search_text].split
  if words.length == 1 then return [[], 0] end
  titles = []
  title_args = []
  words.each do |word|
    titles << "title LIKE ?"
    title_args << "%" + word + "%"
  end
  where_clause = "(" + titles.join(" OR ") + ") " + exclude + " " + restrict
  second_query = make_query.call where_clause, false
  args = title_args
  args += exclude_args
  args += restrict_args
  args += args
  #puts second_query, args.join(",")
  query(con, second_query, *args).each do |res|
    results << make_archived_hash(res)
  end
  return [results, results.length] if results.length < 20
  q = make_query.call where_clause, true
  count = 0
  query(con, q, *args).each do |res|
    count = res["count"]
  end
  return [results, count]
end

