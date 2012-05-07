# -*- coding: utf-8 -*-
# 自動でコネクションを貼り直すStreamer
require File.expand_path File.join(File.dirname(__FILE__), 'streamer')

module ::Plugin::Streaming
  class ParmaStreamer

    # ==== Args
    # [service] 接続するService
    def initialize(service)
      @service = service
      @thread = Thread.new(&method(:mainloop))
      @fail = MikuTwitter::StreamingFailedActions.new('UserStream', Plugin.create(:streaming)) end

    def mainloop
      loop do
        begin
          notice "ParmaStreamer start"
          streamer = Plugin::Streaming::Streamer.new(@service){
            @fail.success
          }
          result = streamer.thread.value
        rescue Net::HTTPError => e
          notice "ParmaStreamer caught exception"
          notice e
          notice "redume..."
          @fail.notify(e)
        rescue Exception => e
          notice "ParmaStreamer caught exception"
          notice e
          notice "redume..."
          @fail.notify(e)
        else
          notice "ParmaStreamer exit"
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
