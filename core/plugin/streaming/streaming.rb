# -*- coding: utf-8 -*-
require File.expand_path File.join(File.dirname(__FILE__), 'parma_streamer')
require File.expand_path File.join(File.dirname(__FILE__), 'filter')

Plugin.create :streaming do
  streamer = UserConfig[:realtime_rewind] && Plugin::Streaming::ParmaStreamer.new(Service.primary)

  rewind_switch_change_hook = UserConfig.connect(:realtime_rewind){ |key, new_val, before_val, id|
    if new_val
      streamer.kill if streamer
      streamer = Plugin::Streaming::ParmaStreamer.new(Service.primary)
    else
      if streamer
        Plugin.call(:rewindstatus, 'UserStream: disconnected')
        streamer.kill
        streamer = nil
      else
        Plugin.call(:rewindstatus, 'UserStream: already disconnected. nothing to do.')
      end
    end
  }

  onunload do
    UserConfig.disconnect(rewind_switch_change_hook)
    streamer.kill if streamer
  end

end
