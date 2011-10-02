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
          users = member - Plugin.filtering(:followings, []).first
          if users.empty?
            sleep(60)
          else
            service.streaming(:filter_stream, :follow => users.map(&:id).join(',')){ |json|
              json.strip!
              err = json
              case json
              when /^\{.*\}$/
                service.__send__(:parse_json, json, :streaming_status) rescue nil end } end
        rescue TimeoutError => e
        rescue => e
          warn e end
        notice 'list stream: disconnected' } } }

end

