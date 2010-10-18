#
# Revolution!
#

require 'timeout'

Module.new do

  @thread = nil

  plugin = Plugin::create(:streaming)

  plugin.add_event(:boot){ |service|
    @service = service
    start if UserConfig[:realtime_rewind] }

  UserConfig.connect(:realtime_rewind){ |key, new_val, before_val, id|
    if new_val
      Delayer.new{ self.start }
    else
      @thread.kill if @thread
    end
  }

  def self.start
    unless @thread and @thread.alive?
      @thread = Thread.new{
        while(UserConfig[:realtime_rewind])
          sleep(3)
          catch(:streaming_break){
            start_streaming{ |q|
              throw(:streaming_break) unless(UserConfig[:realtime_rewind])
              Delayer.new(Delayer::NORMAL, q.strip, &method(:trigger_event)) } } end } end end

  def self.trigger_event(query)
    begin
      return nil if not /^\{.*\}$/ === query
      json = JSON.parse(query)
      case
      when json['friends']
      when json['event'] == 'favorite'
        by = @service.__send__(:parse_json, json['source'], :user_show)
        to = @service.__send__(:parse_json, json['target_object'], :status_show)
        to.first.add_favorited_by(by.first)
        #Plugin.call(:favorite, @service, by.first, to.first)
      when json['event'] == 'unfavorite'
        by = @service.__send__(:parse_json, json['source'], :user_show)
        to = @service.__send__(:parse_json, json['target_object'], :status_show)
        to.first.remove_favorited_by(by.first)
        #Plugin.call(:unfavorite, @service, by.first, to.first)
      when json['delete']
      else
        messages = @service.__send__(:parse_json, json, :streaming_status)
        if messages
          messages.each{ |msg|
            Plugin.call(:update, @service, [msg])
            Plugin.call(:mention, @service, [msg]) if msg.to_me?
            Plugin.call(:mypost, @service, [msg]) if msg.from_me? } end
      end
    rescue Exception => e
      notice e
    end end

  def self.start_streaming(&proc)
    begin
      @service.streaming(&proc)
    rescue Exception => e
      error e
    end
  end
end

