# -*- coding: utf-8 -*-
# aplayコマンドで音を鳴らす

Module.new do

  if command_exist? "aplay"
    Plugin::create(:alsa).add_event(:play_sound){ |filename, &stop|
      SerialThread.new {
        bg_system("aplay","-q", filename) if FileTest.exist?(filename) }
      stop.call } end

end
