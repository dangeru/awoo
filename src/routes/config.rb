############################################
# => config.rb - Configuration for Awoo.
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2018
#
require 'json'
require 'singleton'
class Config
  include Singleton
  attr_accessor :obj

  def self.get
    instance.obj
  end
  def initialize
    config_raw = File.read('config.json')
    @obj = JSON.parse(config_raw)
  end
  def self.rewrite!
    File.open("config.json", "w") do |f|
      f.write(JSON.pretty_generate(Config.get))
    end
  end
end

class ConfigInfra
  include Singleton
  attr_accessor :obj

  def self.get
    instance.obj
  end
  def initialize
    config_raw = File.read('config_infra.json')
    @obj = JSON.parse(config_raw)
  end
  def self.rewrite!
    File.open("config_infra.json", "w") do |f|
      f.write(JSON.pretty_generate(Config.get))
    end
  end
end