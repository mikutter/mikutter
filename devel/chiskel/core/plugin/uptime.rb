#
# 起動時間プラグイン
#

# システムの起動・終了などをTweetする

require File.expand_path(File.join(File.dirname(__FILE__),'..', 'utils'))
require 'plugin/plugin'
require_if_exist 'sys/uptime'

Module.new do

  store = ConfigLoader.create("Plugin::Uptime")
  plugin = Plugin::create(:uptime)

  plugin.add_event(:boot){ |service|
    if FileTest.exist?('/tmp/computer_tweet_uptime') then
      false
    else
      open('/tmp/computer_tweet_uptime','w')
      service.post(:message => "おはよー。 #uptime #period")
    end }

  if defined?(Sys::Uptime)
    plugin.add_event(:period){ |service|
      uptime = Sys::Uptime.seconds
      last = store.at(:last, 0)
      store.store(:last, uptime)
      notice "last=#{dayof(last)}, uptime=#{dayof(uptime)}\n"
      service.post(:message => on_nextday(uptime, last)) if(dayof(uptime) > dayof(last)) }
  end

  def self.dayof(s)
    (s / 86400).to_i
  end

  def self.on_nextday(uptime, last)
    unless dayof(uptime) then return false end
    "連続起動#{dayof(uptime)+1}日目。 #uptime"
  end

end

