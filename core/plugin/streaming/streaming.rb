# -*- coding: utf-8 -*-
require File.join(__dir__, 'perma_streamer')
require File.join(__dir__, 'filter')

Plugin.create :streaming do
  streamers = {}                # service_id => PermaStreamer
  Delayer.new {
    Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.select{|world|
      world.class.slug == :twitter
    }.each{ |service|
      if UserConfig[:realtime_rewind]
        streamers[service.slug] ||= Plugin::Streaming::PermaStreamer.new(service) end } }

  rewind_switch_change_hook = UserConfig.connect(:realtime_rewind){ |key, new_val, before_val, id|
    if new_val
      streamers.values.each(&:kill)
      streamers = {}
      Enumerator.new{|y|
        Plugin.filtering(:worlds, y)
      }.select{|world|
        world.class.slug == :twitter
      }.each{ |service|
        streamers[service.slug] ||= Plugin::Streaming::PermaStreamer.new(service) }
    else
      streamers.values.each(&:kill)
      streamers = {}
    end
  }

  on_service_registered do |service|
    if UserConfig[:realtime_rewind] && service.class.slug == :twitter
      streamers[service.slug] ||= Plugin::Streaming::PermaStreamer.new(service) end end

  on_service_destroyed do |service|
    streamers[service.slug] and streamers[service.slug].kill end

  onunload do
    UserConfig.disconnect(rewind_switch_change_hook)
    streamers.values.each(&:kill)
    streamers = {} end

end
