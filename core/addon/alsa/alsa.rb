# -*- coding: utf-8 -*-
# aplayコマンドで音を鳴らす

Module.new do

  if command_exist? "alsa"
    Plugin::create(:alsa).add_event(:play_sound){ |filename, &stop|
      bg_system("aplay","-q", filename)
      stop.call
    }
  end

end
