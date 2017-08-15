############################################
# => app.rb - Main Renderer
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2017
#

require 'sinatra/base'
require 'json'

require_relative 'routes/boards'
require_relative 'routes/janitor_tools'
require_relative 'routes/errors'

class Awoo < Sinatra::Base
  register Sinatra::Awoo::Routing::Boards
  register Sinatra::Awoo::Routing::Janitorial
  register Sinatra::Awoo::Routing::Errors
  configure do
    set :bind, '0.0.0.0'
    set :port, config['port']
    set :awoo_version, '0.1.0'
    set :public_folder, './static'
  end
  set :root, File.dirname(__FILE__)
  enable :sessions

  get '/' do
    erb :index
  end
end
