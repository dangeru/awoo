############################################
# => errors.rb - Error handlers for Awoo
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2017
#

module Sinatra
  module Awoo
    module Routing
      module Errors
        def self.registered(app)
          app.error 404 do
            erb :notfound
          end

          app.error 500 do
            "Error 500, Internal Server Error. Try again later, we might be busy."
          end
        end
      end
    end
  end
end
