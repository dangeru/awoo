require('minitest/autorun')
require('net/http')
require('json')
require('mysql2')

API = "/api/v2".freeze

class AwooTest < MiniTest::Test
  def initialize(x)
    super(x)
    @host = "127.0.0.1"
    @port = 8080
    @time = Time.new - 10
  end
  def test_post
    assert(not(post_exists("test", "a")))
    assert_success(post("/post", nil, {"board" => "test", "title" => "a", "comment" => ""}))
    assert(post_exists("test", "a"))
  end
  def test_final_teardown
    Mysql2::Client.new(:host => "localhost", :username => "awoo", :password => "awoo", :database => "awoo").query("DELETE FROM posts WHERE date_posted > TIMESTAMP('#{@time.strftime '%m-%d-%YT%H:%M:%S.0000000'}')")
  end
  private
  def assert_success(res)
    res.is_a? Net::HTTPSuccess or res.is_a? Net::HTTPRedirection
  end
  def post_exists(board, title)
    JSON.parse(get(API + "/board/" + board).body).each do |post|
      if post["title"] == title
        return true
      end
    end
    return false
  end
  def get(route, cookie = nil, params = nil)
    uri = URI("http://#{@host}:#{@port}/#{route}")
    uri.query = URI.www_encode_form(params) if params
    Net::HTTP.start(@host, @port) do |http|
      request = Net::HTTP::Get.new uri
      request.add_field("Set-Cookie", cookie) if cookie
      http.request request
    end
  end
  def post(route, cookie = nil, params = nil)
    Net::HTTP.start(@host, @port) do |http|
      request = Net::HTTP::Post.new route
      request.set_form_data(params) if params
      request.add_field("Set-Cookie", cookie) if cookie
      http.request request
    end
  end
end
