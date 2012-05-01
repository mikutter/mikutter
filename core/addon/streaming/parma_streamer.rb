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
      @fail_count = 0
      @wait_time = 0 end

    def mainloop
      loop do
        begin
          notice "ParmaStreamer start"
          streamer = Plugin::Streaming::Streamer.new(@service){
            @fail_count = 0
            @wait_time = 0
          }
          result = streamer.thread.value
        rescue Net::HTTPError => e
          notice "ParmaStreamer caught exception"
          notice e
          notice "redume..."
          httperror
        rescue Exception => e
          notice "ParmaStreamer caught exception"
          notice e
          notice "redume..."
          tcperror
        else
          notice "ParmaStreamer exit"
          notice result
          if result.is_a? Net::HTTPResponse
            httperror
          else
            tcperror end
        ensure
          streamer.kill if streamer
        end
        notice "retry wait #{@wait_time}, fail_count #{@fail_count}"
        sleep @wait_time
      end
    end

    def kill
      @thread.kill
    end

    private

    def tcperror
      @fail_count += 1
      if 1 < @fail_count
        @wait_time += 0.25
        if @wait_time > 16
          @wait_time = 16 end end end

    def httperror
      @fail_count += 1
      if 1 < @fail_count
        if 2 == @fail_count
          @wait_time = 10
        else
          @wait_time *= 2
        if @wait_time > 240
          @wait_time = 240 end end end end

  end
end
