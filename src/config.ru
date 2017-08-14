############################################
# => config.ru - Rackup config file
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2017
#

require File.dirname(__FILE__) + '/app'

puts "Awoo is starting..."
Awoo.run!
