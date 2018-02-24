############################################
# => search.rb - Helper functions for searching for posts
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2018
#

def add_all_linked_titles(ress, con)
  list = ress.select do |x| x[:title].nil? end
  return if list.empty?
  ids = list.map do |x| x[:parent] end.join(",")
  query(con, "SELECT post_id, title FROM posts WHERE post_id IN (#{ids})").each do |res|
    list.each do |l|
      l[:linked_title] = res["title"] if l[:parent] == res["post_id"]
    end
  end
end

def get_search_results(params, con, offset, session, advanced = false)
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
  where_clause = "title LIKE ?) " + exclude + " " + restrict
  make_query = ->(where_clause, for_count, first_only_where_clause) do
    cols = %w(post_id title board).join(", ")
    cols = "COUNT(*) AS count" if for_count
    limit = "LIMIT 20 OFFSET #{offset}"
    limit = "" if for_count
    advanced_cols = (advanced and not for_count) ? ", content, parent, ip, date_posted, janitor" : ""
    advanced_hack = (advanced and not for_count) ? ", NULL AS content, NULL as parent, NULL as ip, NULL as date_posted, NULL as janitor" : ""
    query = "SELECT (SELECT COUNT(*) FROM posts p WHERE posts.post_id = p.post_id OR p.parent = posts.post_id) AS number_of_replies, #{cols}#{advanced_cols} FROM posts WHERE #{first_only_where_clause} #{where_clause}"
    query += " UNION ALL "
    query += "SELECT number_of_posts AS number_of_replies, #{cols}#{advanced_hack} FROM archived_posts WHERE (#{where_clause} #{limit}"
    return query
  end
  first_only_where_clause = advanced ? "(content LIKE ? OR " : "("
  first_query = make_query.call where_clause, false, first_only_where_clause
  results = []
  args = ["%" + params[:search_text] + "%"]
  args += exclude_args
  args += restrict_args
  args += args
  args.insert(0, args[0]) if advanced
  puts first_query, args.join(",")
  query(con, first_query, *args).each do |res|
    results << make_metadata_from_hash(res, session).tap do |x| x[:is_locked] = false end
  end
  if not results.empty?
    q = make_query.call where_clause, true, first_only_where_clause
    count = 0
    query(con, q, *args).each do |res|
      count = res["count"]
    end
    add_all_linked_titles(results, con) if advanced
    return [results, count]
  end
  words = params[:search_text].split
  if words.length == 1 then return [[], 0] end
  # probably gonna split these into two halves
  titles = []
  title_args = []
  first_only_titles = []
  words.each do |word|
    titles << "title LIKE ?"
    first_only_titles << "content LIKE ?" if advanced
    title_args << "%" + word + "%"
  end
  if advanced
    first_only_where_clause = "(" + first_only_titles.join(" OR ") + " OR "
    where_clause = titles.join(" OR ") + ") " + exclude + " " + restrict
    args = title_args + title_args + exclude_args + restrict_args + title_args + exclude_args + restrict_args
  else
    where_clause = titles.join(" OR ") + ") " + exclude + " " + restrict
    args = title_args
    args += exclude_args
    args += restrict_args
    args += args
  end
  second_query = make_query.call where_clause, false, first_only_where_clause
  puts second_query, args.join(",")
  query(con, second_query, *args).each do |res|
    results << make_metadata_from_hash(res, session).tap do |x| x[:is_locked] = false end
  end
  add_all_linked_titles(results, con) if advanced
  return [results, results.length] if results.length < 20
  q = make_query.call where_clause, true, first_only_where_clause
  count = 0
  query(con, q, *args).each do |res|
    count = res["count"]
  end
  return [results, count]
end
