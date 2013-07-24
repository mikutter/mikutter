# -*- coding: utf-8 -*-
require File.expand_path File.join(File.dirname(__FILE__), 'parma_streamer')
require File.expand_path File.join(File.dirname(__FILE__), 'filter')

Plugin.create :streaming do
  streamers = {}                # service_id => ParmaStreamer
  Delayer.new {
    Service.instances.each{ |service|
      if UserConfig[:realtime_rewind]
        streamers[service.name] ||= Plugin::Streaming::ParmaStreamer.new(service) end } }

  rewind_switch_change_hook = UserConfig.connect(:realtime_rewind){ |key, new_val, before_val, id|
    if new_val
      streamers.values.each(&:kill)
      streamers = {}
      Service.instances.each{ |service|
        streamers[service.name] ||= Plugin::Streaming::ParmaStreamer.new(service) }
    else
      Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), _('UserStream: 接続を切りました'), 10)
      streamers.values.each(&:kill)
      streamers = {}
    end
  }

  onunload do
    UserConfig.disconnect(rewind_switch_change_hook)
    streamers.values.each(&:kill)
    streamers = {}
  end

end
