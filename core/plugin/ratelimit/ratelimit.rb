# -*- coding: utf-8 -*-

Plugin.create :ratelimit do
  endpoint_keep_quantity = 3
  less_endpoint = nil

  on_ratelimit do |service, ratelimit|
    Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), "API #{ratelimit.endpoint} #{ratelimit.remain}/#{ratelimit.limit}回くらい (#{ratelimit.reset}まで)", 30)
  end

  on_query_end do |options|
    mikutwitter = options[:mikutwitter]
    service = Service.all.select{ |s| s.twitter == mikutwitter }
    Plugin.call(:ratelimit, service, options[:ratelimit]) if service and options[:ratelimit] end

end
