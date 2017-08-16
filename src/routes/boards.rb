############################################
# => boards.rb - Board Renderer
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2017
#

module Sinatra
  module Awoo
    module Routing
      module Boards
        def self.registered(app)
          config_raw = File.read('config.json')
          config = JSON.parse(config_raw)
          app.set :config, config
          boards = []
          config['boards'].each do |key, array|
            puts "Loading board " + config['boards'][key]['name'] + "..."
            boards << config['boards'][key]['name']
          end

          boards.each do |path|
            app.get "/" + path do
              erb :board, :locals => {:path => path}
            end

            app.post "/" + path + "/post" do
              "title: #{params[:title]}<br>body: #{params[:comment]}"
            end
          end
        end
      end
    end
  end
end
