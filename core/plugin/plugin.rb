#
# Plugin
#

miquire :core, 'configloader'
miquire :core, 'environment'

require 'monitor'

module Plugin
  @@event = Hash.new{ |hash, key| hash[key] = [] } # { event_name => [[plugintag, proc]] }

  def self.add_event(event_name, tag, &callback)
    @@event[event_name.to_sym] << [tag, callback]
    callback end

  def self.call(event_name, *args)
    @@event[event_name.to_sym].each{ |plugin|
      Delayer.new{
        plugin[1].call(*args) } } end

  def self.create(name)
    PluginTag.create(name) end

  # return {tag => {event => [proc]}}
  def self.plugins
    result = Hash.new{ |hash, key|
      hash[key] = Hash.new{ |hash, key|
        hash[key] = [] } }
    @@event.each_pair{ |event, pair|
      result[pair[0]][event] << proc
    }
    result
  end

end

class Plugin::PluginTag
  @@plugins = [] # plugin

  attr_reader :name

  def initialize(name = :anonymous)
    @name = name
    regist end

  def self.create(name)
    plugin = @@plugins.find{ |p| p.name == name }
    if plugin
      plugin
    else
      Plugin::PluginTag.new(name) end end

  def add_event(event_name, &callback)
    Plugin.add_event(event_name, self, &callback)
  end

  private

  def regist
    atomic{
      @@plugins.push(self) } end
end

miquire :plugin
