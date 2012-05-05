# -*- coding: utf-8 -*-
# リストをリアルタイム化

Plugin::create(:liststream) do
  thread = nil
  @fail_count = @wait_time = 0

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
    service = Service.primary
    @success_flag = false
    @fail = MikuTwitter::StreamingFailedActions.new("List Stream", self)
    Thread.new{
      loop{
        notice 'list stream: connect'
        begin
          not_followings = member_anything_and_not_following
          if not_followings.empty?
            sleep(60)
          else
            notice "followings #{not_followings.size} people"
            r = service.streaming(:filter_stream, :follow => not_followings.to_a[0, 5000].map(&:id).join(',')){ |json|
              json.strip!
              case json
              when /^\{.*\}$/
                if @success_flag
                  @fail.success
                  @success_flag = true end
                MikuTwitter::ApiCallSupport::Request::Parser.message(JSON.parse(json).symbolize) rescue nil
              end }
            raise r if r.is_a? Exception
            notice "list stream: disconnected #{r}"
            streamerror r
          end
        rescue Net::HTTPError => e
          notice "list stream: disconnected: #{e.code} #{e.body}"
          streamerror e
          warn e
        rescue Exception => e
          notice "list stream: disconnected: exception #{e}"
          streamerror e
          warn e end
        notice "retry wait #{@fail.wait_time}, fail_count #{@fail.fail_count}"
        sleep @fail.wait_time } }
  end

  def streamerror(e)
    @success_flag = false
    @fail.notify(e) end

end

