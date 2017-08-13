############################################
# => app.rb - Main Renderer
# => Awoo Textboard Engine
# => Version 0.0.1
# => (c) prefetcher & github commiters 2017
#

require 'sinatra/base'

require_relative 'routes/boards'
require_relative 'routes/janitor_tools'

class Awoo < Sinatra::Base
  set :root, File.dirname(__FILE__)
  enable :sessions
  configure do
    set :bind, '0.0.0.0'
  end

  get '/' do
    'main renderer - testing'
  end

  register Sinatra::Awoo::Routing::Boards
  register Sinatra::Awoo::Routing::Janitorial
end
