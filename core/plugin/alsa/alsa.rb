# -*- coding: utf-8 -*-
# aplayコマンドで音を鳴らす

Plugin.create :alsa do

  defsound :alsa, "ALSA" do |filename|
    spawn("aplay","-q", filename) if FileTest.exist?(filename) end

end
