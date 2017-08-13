############################################
# => app.rb - Main Renderer
# => Awoo Textboard Engine
# => Version 0.0.1
# => (c) prefetcher & github commiters 2017
#

require 'sinatra/base'
require 'json'

require_relative 'routes/boards'
require_relative 'routes/janitor_tools'

class Awoo < Sinatra::Base
  config_raw = File.read('config.json')
  config = JSON.parse(config_raw)
  configure do
    set :bind, '0.0.0.0'
    set :port, config['port']
  end
  set :root, File.dirname(__FILE__)
  enable :sessions

  boards = ""
  config['boards'].each do |key, array|
    boards += config['boards'][key]['name'] + ", "
  end

  get '/' do
    "#{config['title']} is running on port #{config['port']}, currently avaiable boards: #{boards}"
  end

  register Sinatra::Awoo::Routing::Boards
  register Sinatra::Awoo::Routing::Janitorial
end
