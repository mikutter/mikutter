# -*- coding: utf-8 -*-
# 自動でコネクションを貼り直すStreamer
require File.expand_path File.join(File.dirname(__FILE__), 'streamer')

module ::Plugin::Streaming
  class PermaStreamer

    # ==== Args
    # [service] 接続するService
    def initialize(service)
      @service = service
      @thread = Thread.new(&method(:mainloop))
      @fail = MikuTwitter::StreamingFailedActions.new('UserStream', Plugin.create(:streaming)) end

    def mainloop
      loop do
        begin
          streamer = Plugin::Streaming::Streamer.new(@service){
            @fail.success
          }
          result = streamer.thread.value
        rescue Net::ReadTimeout => exception
          @fail.notify(exception)
        rescue Net::HTTPError => exception
          warn "PermaStreamer caught exception"
          warn exception
          @fail.notify(exception)
        rescue Exception => exception
          warn "PermaStreamer caught exception"
          warn exception
          @fail.notify(exception)
        else
          notice "PermaStreamer exit"
          notice result
          @fail.notify(result)
        ensure
          streamer.kill if streamer
        end
        notice "retry wait #{@fail.wait_time}, fail_count #{@fail.fail_count}"
        sleep @fail.wait_time
      end
    end

    def kill
      @thread.kill
    end

  end
end
