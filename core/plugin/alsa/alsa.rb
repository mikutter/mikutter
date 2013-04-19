# -*- coding: utf-8 -*-
# aplayコマンドで音を鳴らす

Plugin.create :alsa do

  aplay_exist = command_exist?('aplay')

  defsound :alsa, "ALSA" do |filename|
    bg_system("aplay","-q", filename) if FileTest.exist?(filename) and aplay_exist end

end
