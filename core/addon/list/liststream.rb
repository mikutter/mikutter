# -*- coding: utf-8 -*-
# リストをリアルタイム化

Plugin::create(:liststream) do
  thread = nil
  Delayer.new {
    thread = start if UserConfig[:list_realtime_rewind]
    UserConfig.connect(:list_realtime_rewind) do |key, new_val, before_val, id|
      if new_val
        notice 'list stream: enable'
        thread = start unless thread.is_a? Thread
      else
        notice 'list stream: disable'
        thread.kill if thread.is_a? Thread
        thread = nil end end }

  on_list_member_changed do |userlist|
    if UserConfig[:list_realtime_rewind]
      thread.kill rescue nil if thread
      thread = start end end

  # 表示対象のListのうち、いずれかに所属するUserを含んだEnumerableを返す。
  # 呼ぶたびにフィルタを利用するので負荷が高いため、注意する。
  def member_anything
    Plugin.filtering(:displayable_lists, Set.new).first.inject(Set.new) { |member, list|
      if list
        member + list[:member]
      else
        member end } end

  # _member_anything_ のうち、自分がフォローしているユーザを除くUserを含んだEnumerableを返す。
  def member_anything_and_not_following
    member_anything - Plugin.filtering(:followings, Set.new).first end

  def start
    service = Service.services.first
    Thread.new{
      loop{
        sleep(3)
        notice 'list stream: connect'
        begin
          not_followings = member_anything_and_not_following
          if not_followings.empty?
            sleep(60)
          else
            timeout(3600) {
              notice "followings #{not_followings.size} people"
              service.streaming(:filter_stream, :follow => not_followings.to_a[0, 5000].map(&:id).join(',')){ |json|
                json.strip!
                case json
                when /^\{.*\}$/
                  MikuTwitter::ApiCallSupport::Request::Parser.message(JSON.parse(json).symbolize) rescue nil
                end } } end
        rescue TimeoutError => e
        rescue => e
          warn e end
        notice 'list stream: disconnected' } }
  end

end

