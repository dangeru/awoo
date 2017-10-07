require 'rubygems'
require 'mysql2'
require 'json'
con = Mysql2::Client.new(:host => "localhost", :username => "awoo", :password => "awoo", :database => "awoo")
config_raw = File.read(File.dirname(__FILE__) + '/config.json')
config = JSON.parse(config_raw)
con.query("UPDATE posts SET is_locked = TRUE WHERE UNIX_TIMESTAMP(CURRENT_TIMESTAMP()) - UNIX_TIMESTAMP(last_bumped) > #{config["seconds_until_archival"]} AND parent IS NULL AND NOT sticky")
