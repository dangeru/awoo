require 'rubygems'
require 'mysql2'
require 'json'

con = Mysql2::Client.new(:host => ConfigInfra.get["mysql_host"], :username => ConfigInfra.get["mysql_user"], :password => ConfigInfra.get["mysql_password"], :database => ConfigInfra.get["mysql_database"])

config_raw = File.read(File.dirname(__FILE__) + '/config.json')
config = JSON.parse(config_raw)
con.query("UPDATE posts SET is_locked = TRUE WHERE UNIX_TIMESTAMP(CURRENT_TIMESTAMP()) - UNIX_TIMESTAMP(last_bumped) > #{config["seconds_until_archival"]} AND parent IS NULL AND NOT sticky")
