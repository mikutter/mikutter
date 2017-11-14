# -*- coding: utf-8 -*-

Module.new do

  Plugin.create(:core) do

    # イベントフィルタを他のスレッドで並列実行する
    Delayer.new do
      Event.filter_another_thread = true end

  end

end
