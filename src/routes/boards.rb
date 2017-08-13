############################################
# => boards.rb - Board Renderer
# => Awoo Textboard Engine
# => Version 0.0.1
# => (c) prefetcher & github commiters 2017
#

module Sinatra
  module Awoo
    module Routing
      module Boards
        def self.registered(app)
          app.get '/a' do
            "board renderer - test"
          end
        end
      end
    end
  end
end
