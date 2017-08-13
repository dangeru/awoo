############################################
# => config.ru - Rackup config file
# => Awoo Textboard Engine
# => Version 0.0.3
# => (c) prefetcher & github commiters 2017
#

require File.dirname(__FILE__) + '/app'

puts "Awoo is starting..."
Awoo.run!
