# -*- coding: utf-8 -*-

Plugin.create :core do

  # appearイベントには二回以上同じMessageを渡さない
  @appear_fired = Set.new
  filter_appear do |messages|
    [ messages.select{ |m|
        if not @appear_fired.include?(m[:id])
          @appear_fired << m[:id] end } ] end

end
