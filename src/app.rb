############################################
# => app.rb - Main Renderer
# => Awoo Textboard Engine
# => Version 0.0.3
# => (c) prefetcher & github commiters 2017
#

require 'sinatra/base'
require 'json'

require_relative 'routes/boards'
require_relative 'routes/janitor_tools'

class Awoo < Sinatra::Base
  register Sinatra::Awoo::Routing::Boards
  register Sinatra::Awoo::Routing::Janitorial
  boards = "<br>"
  settings.config['boards'].each do |key, array|
    boards += '<a href="/' + settings.config['boards'][key]['name'] + '">' + settings.config['boards'][key]['name'] + '</a><br>'
  end
  configure do
    set :bind, '0.0.0.0'
    set :port, config['port']
  end
  set :root, File.dirname(__FILE__)
  enable :sessions


  get '/' do
    "#{settings.config['title']} is running on port #{settings.config['port']}, currently avaiable boards: #{boards}"
  end

end
