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
    assert(not(find_post("test", "a")))
    assert(is_success(post("/post", nil, {"board" => "test", "title" => "a", "comment" => ""})))
    post = find_post("test", "a")
    assert(post)
    assert(post["capcode"].nil?)
    cookie = login("test")
    assert(is_success(post("/post", cookie, {"board" => "test", "title" => "b", "comment" => "", "capcode" => "true"})))
    assert(find_post("test", "b")["capcode"] == "test")
  end
  def test_final_teardown
    Mysql2::Client.new(:host => "localhost", :username => "awoo", :password => "awoo", :database => "awoo").query("DELETE FROM posts WHERE date_posted > TIMESTAMP('#{@time.strftime '%m-%d-%YT%H:%M:%S.0000000'}')")
  end
  private
  def is_success(res)
    res.is_a? Net::HTTPSuccess or res.is_a? Net::HTTPRedirection
  end
  def find_post(board, title, cookie = nil)
    JSON.parse(get(API + "/board/" + board, cookie).body).each do |post|
      if post["title"] == title
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
