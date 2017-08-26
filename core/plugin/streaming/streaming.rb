# -*- coding: utf-8 -*-
require File.join(__dir__, 'perma_streamer')
require File.join(__dir__, 'filter')

Plugin.create :streaming do
  streamers = {}                # service_id => PermaStreamer
  Delayer.new {
    Service.instances.each{ |service|
      if UserConfig[:realtime_rewind]
        streamers[service.name] ||= Plugin::Streaming::PermaStreamer.new(service) end } }

  on_userconfig_modify do |key, new_val|
    if new_val
      streamers.values.each(&:kill)
      streamers = {}
      Service.instances.each{ |service|
        streamers[service.name] ||= Plugin::Streaming::PermaStreamer.new(service) }
    else
      streamers.values.each(&:kill)
      streamers = {}
    end
  end

  on_service_registered do |service|
    if UserConfig[:realtime_rewind]
      streamers[service.name] ||= Plugin::Streaming::PermaStreamer.new(service) end end

  on_service_destroyed do |service|
    streamers[service.name] and streamers[service.name].kill end

  onunload do
    streamers.values.each(&:kill)
    streamers = {} end

end
