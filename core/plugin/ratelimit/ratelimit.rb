# -*- coding: utf-8 -*-
require 'set'

Plugin.create :ratelimit do
  defactivity "ratelimit", "規制通知"

  notificated = Set.new
  ratelimit_filter_mutex = Mutex.new

  on_ratelimit do |service, ratelimit|
    Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), "API #{ratelimit.endpoint} #{ratelimit.remain}/#{ratelimit.limit}回くらい (#{ratelimit.reset.strftime('%Y/%m/%d %H:%M:%S')}まで)", 30)
    if ratelimit.limit?
      title = "エンドポイント `#{ratelimit.endpoint}' が規制されました。#{ratelimit.reset.strftime('%Y/%m/%d %H:%M:%S')}に解除されます。"
      activity(:ratelimit, title,
               service: service,
               description: "#{title}\n#{ratelimit.endpoint} は15分に #{ratelimit.limit} 回までのアクセスが許可されています。頻発するようなら同時に使用するTwitterクライアントを減らすか、設定を見直しましょう")
    end
  end

  on_mikutwitter_ratelimit do |mikutwitter, ratelimit|
    service = Service.all.select{ |s| s.twitter == mikutwitter }
    notice "ratelimit: #{ratelimit}"
    Plugin.call(:ratelimit, service, ratelimit) if service and ratelimit end

  filter_ratelimit do |service, ratelimit|
    ratelimit_filter_mutex.synchronize {
      if notificated.include? ratelimit
        Plugin.filter_cancel!
      else
        notificated << ratelimit
        Reserver.new(ratelimit.reset){ notificated.delete(ratelimit) } end }
    [service, ratelimit]
  end

end
