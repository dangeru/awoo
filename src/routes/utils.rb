############################################
# => utils.rb - Utilities for Awoo.
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2018
#

require_relative 'config.rb'
%w(general moderation unified_load_interface search page_generators).each do |f| require_relative "utils/#{f}.rb" end
