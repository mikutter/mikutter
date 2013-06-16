# -*- coding: utf-8 -*-
require File.expand_path File.join(File.dirname(__FILE__), 'parma_streamer')
require File.expand_path File.join(File.dirname(__FILE__), 'filter')

Plugin.create :streaming do
  streamer = nil
  Delayer.new {
    streamer = UserConfig[:realtime_rewind] && Plugin::Streaming::ParmaStreamer.new(Service.primary) }

  rewind_switch_change_hook = UserConfig.connect(:realtime_rewind){ |key, new_val, before_val, id|
    if new_val
      streamer.kill if streamer
      streamer = Plugin::Streaming::ParmaStreamer.new(Service.primary)
    else
      if streamer
        Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), _('UserStream: 接続を切りました'), 10)
        streamer.kill
        streamer = nil
      else
        # 無効にされたがすでに接続が切れていた場合
        Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), _('UserStream: 接続を無効にしました'), 10)
      end
    end
  }

  onunload do
    UserConfig.disconnect(rewind_switch_change_hook)
    streamer.kill if streamer
  end

end
