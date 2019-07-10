############################################
# => general.rb - General utilities for Awoo.
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2018
#

require 'mysql2'

# Helper function for connecting to the database
def make_con()
  return Mysql2::Client.new(:host => "localhost", :username => "awoo", :password => "awoo", :database => "awoo")
end

def query(con, stmt, *args)
  return con.prepare(stmt).execute(*args)
end

# Attempts to pick a random banner for the given board
def new_banner(board)
  if board.index("..") != nil
    return ""
  end
  if board == "all"
    # glob all banners from all boards
    dirs = Dir['./static/static/banners/*/*']
    banner = dirs.select {|f| !File.directory? f}.sample

    # gsub `./static` out of it
    banner.sub! "./static", ""
    return banner
  end
  begin
    # this will throw an exception if the folder doesn't exist, hence the rescue
    dirs = Dir.entries(File.dirname(__FILE__) + "/../../static/static/banners/" + board)
    # we have to remove "." and ".." from the list, but this will also remove all hidden files
    return "/static/banners/" + board + "/" + dirs.select {|f| !File.directory? f}.sample
  rescue
    # no banners for this board, just use the logo
    return "/static/logo.png"
  end
end

def format_news(news)
  return DateTime.strptime(news["timestamp"].to_s, "%s").strftime("%d/%m/%y") + ": " + news["text"]
end

# this function tries to get the IP from the request, and if we're behind a reverse proxy it tries to get it from the environment variables
def get_ip(request, env)
  env["HTTP_CF_CONNECTING_IP"] || env["HTTP_X_FORWARDED_FOR"] || request.ip
end

# read mobile.js into a string so the client on the phone doesn't have to make an extra request for it
# actually does speed up load time on mobile because the mobile page is gonna look like shit until it loads this javascript
def mobile_js()
  res = ""
  f = File.open(File.dirname(__FILE__) + "/../../static/static/mobile.js", "r")
  f.each_line do |line|
    res += line;
  end
  f.close
  return res
end

