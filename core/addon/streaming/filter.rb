# -*- coding: utf-8 -*-

require 'set'

Plugin.create :streaming do
  thread = nil
  @fail_count = @wait_time = 0

  Delayer.new {
    thread = start if UserConfig[:filter_realtime_rewind]
    UserConfig.connect(:filter_realtime_rewind) do |key, new_val, before_val, id|
      if new_val
        notice 'filter stream: enable'
        thread = start unless thread.is_a? Thread
      else
        notice 'filter stream: disable'
        thread.kill if thread.is_a? Thread
        thread = nil end end }

  on_filter_stream_force_retry do
    if UserConfig[:filter_realtime_rewind]
      thread.kill rescue nil if thread
      thread = start end end

  def start
    service = Service.primary
    @success_flag = false
    @fail = MikuTwitter::StreamingFailedActions.new("Filter Stream", self)
    Thread.new{
      loop{
        notice 'filter stream: connect'
        begin
          follow = Plugin.filtering(:filter_stream_follow, Set.new).first || Set.new
          track = Plugin.filtering(:filter_stream_track, "").first || ""
          notice "followings #{follow.size} people, track keyword '#{track}'"
          if follow.empty? && track.empty?
            sleep(60)
          else
            param = {}
            param[:follow] = follow.to_a[0, 5000].map(&:id).join(',') if not follow.empty?
            param[:track] = track if not track.empty?
            r = service.streaming(:filter_stream, param){ |json|
              json.strip!
              case json
              when /^\{.*\}$/
                if @success_flag
                  @fail.success
                  @success_flag = true end
                MikuTwitter::ApiCallSupport::Request::Parser.message(JSON.parse(json).symbolize) rescue nil
              end }
            raise r if r.is_a? Exception
            notice "filter stream: disconnected #{r}"
            streamerror r
          end
        rescue Net::HTTPError => e
          notice "filter stream: disconnected: #{e.code} #{e.body}"
          streamerror e
          warn e
        rescue Exception => e
          notice "filter stream: disconnected: exception #{e}"
          streamerror e
          warn e end
        notice "retry wait #{@fail.wait_time}, fail_count #{@fail.fail_count}"
        sleep @fail.wait_time } }
  end

  def streamerror(e)
    @success_flag = false
    @fail.notify(e) end

end
