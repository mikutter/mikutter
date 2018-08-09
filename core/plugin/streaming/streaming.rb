# -*- coding: utf-8 -*-

require 'set'

Plugin.create :streaming do
  thread = nil
  @fail_count = @wait_time = 0
  reconnect_request_flag = false

  on_filter_stream_force_retry do
    if UserConfig[:filter_realtime_rewind]
      thread.kill rescue nil if thread
      thread = start end end

  on_filter_stream_reconnect_request do
    if not reconnect_request_flag
      reconnect_request_flag = true
      Reserver.new(30, thread: Delayer) {
        reconnect_request_flag = false
        Plugin.call(:filter_stream_force_retry) } end end

  def start
    twitter = Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.find{|world|
      world.class.slug == :twitter
    }
    return unless twitter
    @success_flag = false
    @fail = MikuTwitter::StreamingFailedActions.new("Filter Stream", self)
    Thread.new{
      loop{
        begin
          follow = Plugin.filtering(:filter_stream_follow, Set.new).first || Set.new
          track = Plugin.filtering(:filter_stream_track, "").first || ""
          if follow.empty? && track.empty?
            sleep(60)
          else
            param = {}
            param[:follow] = follow.to_a[0, 5000].map(&:id).join(',') if not follow.empty?
            param[:track] = track if not track.empty?
            r = twitter.streaming(:filter_stream, param){ |json|
              json.strip!
              case json
              when /\A\{.*\}\Z/
                if @success_flag
                  @fail.success
                  @success_flag = true end
                parsed = JSON.parse(json).symbolize
                if not parsed[:retweeted_status]
                  MikuTwitter::ApiCallSupport::Request::Parser.streaming_message(parsed) rescue nil end
              end }
            raise r if r.is_a? Exception
            notice "filter stream: disconnected #{r}"
            streamerror r
          end
        rescue Net::HTTPError => exception
          warn "filter stream: disconnected: #{exception.code} #{exception.body}"
          streamerror exception
          warn exception
        rescue Net::ReadTimeout => exception
          streamerror exception
        rescue Exception => exception
          warn "filter stream: disconnected: exception #{exception}"
          streamerror exception
          warn exception end
        notice "retry wait #{@fail.wait_time}, fail_count #{@fail.fail_count}"
        sleep @fail.wait_time } }
  end

  def streamerror(exception)
    @success_flag = false
    @fail.notify(exception) end

  on_userconfig_modify do |key, new_val|
    next if key != :filter_realtime_rewind
    if new_val
      notice 'filter stream: enable'
      thread = start unless thread.is_a? Thread
    else
      notice 'filter stream: disable'
      thread.kill if thread.is_a? Thread
      thread = nil
    end
  end

  Delayer.new do
    thread = start if UserConfig[:filter_realtime_rewind]
  end

end
