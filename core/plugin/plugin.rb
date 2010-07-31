#
# Plugin
#

miquire :core, 'configloader'
miquire :core, 'environment'
miquire :core, 'delayer'

require 'monitor'

module Plugin
  @@event          = Hash.new{ |hash, key| hash[key] = [] } # { event_name => [[plugintag, proc]] }
  @@add_event_hook = Hash.new{ |hash, key| hash[key] = [] }

  def self.add_event(event_name, tag, &callback)
    @@event[event_name.to_sym] << [tag, callback]
    call_add_event_hook(callback, event_name)
    callback end

  def self.fetch_event(event_name, tag, &callback)
    call_add_event_hook(callback, event_name)
    callback end

  def self.add_event_hook(event_name, tag, &callback)
    @@add_event_hook[event_name.to_sym] << [tag, callback]
    callback end

  def self.detach(event_name, event)
    @@event[event_name.to_sym].delete_if{ |e| e[1] == event } end

  def self.call(event_name, *args)
    @@event[event_name.to_sym].each{ |plugin|
      Delayer.new{
        plugin[1].call(*args) } } end

  def self.call_add_event_hook(event, event_name)
    @@add_event_hook[event_name.to_sym].each{ |plugin|
      Delayer.new{
        plugin[1].call(event) } } end

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

  include ConfigLoader

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

  def fetch_event(event_name, &callback)
    Plugin.fetch_event(event_name, self, &callback)
  end

  def add_event_hook(event_name, &callback)
    Plugin.add_event_hook(event_name, self, &callback)
  end

  def self.detach(event)
    Plugin.detach(event_name, event)
  end

  def at(key, ifnone=nil)
    super("#{@name}_#{key}".to_sym, ifnone) end

  def store(key, val)
    super("#{@name}_#{key}".to_sym, val) end

  private

  def regist
    atomic{
      @@plugins.push(self) } end
end

miquire :plugin
