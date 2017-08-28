require('minitest/autorun')
require('net/http')
require('json')
require('mysql2')
require('http-cookie')

API = "/api/v2".freeze
Dummy_uri = "http://dummy/".freeze

class AwooTest < MiniTest::Test
  def initialize(x)
    super(x)
    @host = "127.0.0.1"
    @port = 8080
    @time = Time.new.utc - 1
  end
  def test_post
    # Make sure the post shows up
    assert(not(find_post("test", "a")))
    assert(is_success(post("/post", nil, {"board" => "test", "title" => "a", "comment" => ""})))
    post = find_post("test", "a")
    assert(post)
    assert(post["capcode"].nil?)
    # Make sure that posting with a capcode works
    cookie = login("test")
    assert(is_success(post("/post", cookie, {"board" => "test", "title" => "b", "comment" => "", "capcode" => "true"})))
    assert(find_post("test", "b")["capcode"] == "test")
    # Make sure that replying works
    assert(not(find_reply(post["post_id"], "c")))
    assert(is_success(post("/reply", nil, {"board" => "test", "parent" => post["post_id"], "content" => "c"})))
    reply = find_reply(post["post_id"], "c")
    assert(reply["capcode"].nil?)
    # Make sure that replying with a capcode works
    assert(is_success(post("/reply", cookie, {"board" => "test", "parent" => post["post_id"], "content" => "d", "capcode" => "true"})))
    assert(find_reply(post["post_id"], "d")["capcode"] == "test")
  end
  def test_sticky
    sleep 1
    assert(is_success(post("/post", nil, {"board" => "test", "title" => "e", "comment" => ""})))
    sleep 1
    assert(is_success(post("/post", nil, {"board" => "test", "title" => "f", "comment" => ""})))
    sleep 1
    # f should appear before e
    board = get_board("test")
    assert(board[0]["title"] == "f")
    assert(board[1]["title"] == "e")
    # after stickying e, e should appear before f
    epost = find_post("test", "e")
    assert not(epost["sticky"])
    cookie = login("test")
    assert(is_success(get("/sticky/" + epost["post_id"].to_s, cookie)))
    sleep 1
    board = get_board("test")
    assert(board[0]["title"] == "e")
    assert(board[1]["title"] == "f")
    # and e should now be marked as sticky
    epost = find_post("test", "e")
    assert epost["sticky"]
    # after stickying f, f should again appear before e
    fpost = find_post("test", "f")
    assert not(fpost["sticky"])
    assert(is_success(get("/sticky/" + fpost["post_id"].to_s, cookie)))
    sleep 1
    board = get_board("test")
    assert(board[0]["title"] == "f")
    assert(board[1]["title"] == "e")
    # after adjusting the stickyness on e to 2, e should appear before f
    assert(is_success(post("/sticky/" + epost["post_id"].to_s, cookie, {"stickyness" => "2"})))
    sleep 1
    board = get_board("test")
    assert(board[0]["title"] == "e")
    assert(board[1]["title"] == "f")
    # Check it's stickyness
    epost = find_post("test", "e")
    assert(epost["stickyness"] == 2)
    # Unsticky e
    assert(is_success(get("/unsticky/" + epost["post_id"].to_s, cookie)))
    sleep 1
    epost = find_post("test", "e")
    assert(not(epost["sticky"]))
    # try and sticky e while not logged in, make sure it fails
    assert(not(is_success(get("/sticky/" + epost["post_id"].to_s))))
    sleep 1
    epost = find_post("test", "e")
    assert(not(epost["sticky"]))
    # try and adjust stickyness on f while not logged in, make sure it fails
    assert(not(is_success(post("/sticky/" + fpost["post_id"].to_s, nil, {"stickyness" => 2}))))
    sleep 1
    fpost = find_post("test", "f")
    assert(fpost["stickyness"] == 1) # should have been unchanged
  end
  def test_final_teardown
    Mysql2::Client.new(:host => "localhost", :username => "awoo", :password => "awoo", :database => "awoo").query("DELETE FROM posts WHERE date_posted > TIMESTAMP('#{@time.strftime '%m-%d-%YT%H:%M:%S.0000000'}')")
  end
  private
  def is_success(res)
    res.is_a? Net::HTTPSuccess or res.is_a? Net::HTTPRedirection
  end
  def get_board(board, cookie = nil)
    JSON.parse(get(API + "/board/" + board, cookie).body)
  end
  def find_post(board, title, cookie = nil)
    get_board(board, cookie).each do |post|
      if post["title"] == title
        return post
      end
    end
    return false
  end
  def find_reply(id, content, cookie = nil)
    JSON.parse(get(API + "/thread/" + id.to_s + "/replies", cookie).body).each do |post|
      if post["comment"] == content
        return post
      end
    end
    return false
  end
  def login(user)
    pass = nil
    File.open(File.dirname(__FILE__) + "/../config.json") do |f|
      JSON.parse(f.read)["janitors"].each do |mod|
        if mod["username"] == user then
          pass = mod["password"]
          break
        end
      end
    end
    res = post("/mod", nil, {"username": user, "password": pass})
    jar = HTTP::CookieJar.new
    res.get_fields("Set-Cookie").each do |value|
      jar.parse(value, Dummy_uri)
    end
    jar
  end
  def get(route, cookie = nil, params = nil)
    uri = URI("http://#{@host}:#{@port}/#{route}")
    uri.query = URI.www_encode_form(params) if params
    Net::HTTP.start(@host, @port) do |http|
      request = Net::HTTP::Get.new uri
      request["Cookie"] = HTTP::Cookie.cookie_value(cookie.cookies) if cookie
      http.request request
    end
  end
  def post(route, cookie = nil, params = nil)
    Net::HTTP.start(@host, @port) do |http|
      request = Net::HTTP::Post.new route
      request.set_form_data(params) if params
      request["Cookie"] = HTTP::Cookie.cookie_value(cookie.cookies) if cookie
      http.request request
    end
  end
end
