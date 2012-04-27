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
    end

    def mainloop
      loop do
        sleep 3
        begin
          notice "ParmaStreamer start"
          streamer = Plugin::Streaming::Streamer.new(@service)
          result = streamer.thread.join
        rescue => e
          notice "ParmaStreamer caught exception"
          notice e
          notice "redume..."
        else
          notice "ParmaStreamer exit"
          into_debug_mode nil, binding if not result.is_a? Thread
          notice result
        ensure
          streamer.kill if streamer
        end
      end
    end

    def kill
      @thread.kill
    end

  end
end
