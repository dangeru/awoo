############################################
# => vichan_compat.rb - vichan compatibility layer for Awoo.
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2017
#

require_relative 'utils'

def bool_to_i(b)
  return 1 if b
  return 0
end

module Sinatra
  module Awoo
    module Routing
      module VichanCompat
        def self.registered(app)
          config_raw = File.read('config.json')
          config = JSON.parse(config_raw)
          config["boards"].select do |k, board| not board["hidden"] end.each do |path, board|
            app.get "/" + path + "/catalog.json" do
              result = []
              page = 0
              while true do
                this_page = get_board(path, {:page => page}, session, config)
                if this_page.length == 0 then
                  break
                end
                page_hash = {:threads => [], :page => page}
                this_page.each do |thread|
                  vichan_thread = {:no => thread[:post_id], :sub => thread[:title], :com => thread[:comment], :name => thread[:hash], :time => thread[:date_posted], :last_modified => thread[:last_bumped], :omitted_posts => 0, :omitted_images => 0, :replies => thread[:number_of_replies], :images => 0, :sticky => bool_to_i(thread[:sticky]), :locked => bool_to_i(thread[:is_locked]), :cyclical => "0", :tn_h => 0, :tn_w => 0, :h => 0, :w => 0, :fsize => 0, :filename => "dne", :ext => ".png", :tim => "dne", :md5 => "", :resto => 0}
                  if thread[:capcode] then
                    vichan_thread[:capcode] = thread[:capcode]
                  end
                  page_hash[:threads].push vichan_thread
                end
                result.push page_hash
                page += 1
              end
              JSON.dump(result)
            end
            app.get "/" + path + "/thread/:id.json" do |id|
              "todo"
            end
          end
        end
      end
    end
  end
end
