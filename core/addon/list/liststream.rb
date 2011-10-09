# -*- coding: utf-8 -*-
# リストをリアルタイム化

Plugin::create(:liststream) do
  Delayer.new {
    service = Post.services.first

    Thread.new{
      loop{
        sleep(3)
        notice 'list stream: connect'
        begin
          member = Plugin.filtering(:displayable_lists, []).first.inject(Set.new){ |member, list|
            if list
              member + list[:member]
            else
              member end }
          not_followings = member - Plugin.filtering(:followings, []).first
          if not_followings.empty?
            sleep(60)
          else
            service.streaming(:filter_stream, :follow => not_followings.map(&:id).join(',')){ |json|
              json.strip!
              case json
              when /^\{.*\}$/
                service.__send__(:parse_json, json, :streaming_status) rescue nil end } end
        rescue TimeoutError => e
        rescue => e
          warn e end
        notice 'list stream: disconnected' } } }

end

