# -*- coding: utf-8 -*-
require 'set'

Plugin.create :ratelimit do
  defactivity "ratelimit", _("規制通知")

  notificated = Set.new
  ratelimit_filter_mutex = Mutex.new

  on_ratelimit do |service, ratelimit|
    Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), _("API %{endpoint} %{remain}/%{limit}回くらい (%{refresh_time}まで)") % {
                  endpoint: ratelimit.endpoint,
                  remain: ratelimit.remain,
                  limit: ratelimit.limit,
                  refresh_time: ratelimit.reset.strftime(_('%Y/%m/%d %H:%M:%S'))
                }, 30)
    if ratelimit.limit?
      title = _("エンドポイント `%{endpoint}' が規制されました。%{refresh_time}に解除されます。") % {
        endpoint: ratelimit.endpoint,
        refresh_time: ratelimit.reset.strftime(_('%Y/%m/%d %H:%M:%S')) }
      activity(:ratelimit, title,
               service: service,
               description: "#{title}\n" + _("%{endpoint} は%{minute}分に %{limit} 回までのアクセスが許可されています。頻発するようなら同時に使用するTwitterクライアントを減らすか、設定を見直しましょう") % {
                 endpoint: ratelimit.endpoint,
                 minute: 15,
                 limit: ratelimit.limit })
    end
  end

  on_mikutwitter_ratelimit do |mikutwitter, ratelimit|
    service = Service.select{ |s| s.twitter == mikutwitter }
    Plugin.call(:ratelimit, service, ratelimit) if service and ratelimit end

  filter_ratelimit do |service, ratelimit|
    ratelimit_filter_mutex.synchronize {
      if notificated.include? ratelimit
        Plugin.filter_cancel!
      else
        notificated << ratelimit
        Reserver.new(ratelimit.reset, thread: Thread){ notificated.delete(ratelimit) } end }
    [service, ratelimit]
  end

end
