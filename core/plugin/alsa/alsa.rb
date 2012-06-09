# -*- coding: utf-8 -*-
# aplayコマンドで音を鳴らす

Plugin.create :alsa do

  on_play_sound do |filename, &stop|
    if command_exist? "aplay"
      SerialThread.new {
        bg_system("aplay","-q", filename) if FileTest.exist?(filename) }
      stop.call end end

end
