#
# post.rb
#

# タイムラインやポストを管理する

miquire :core, 'twitter'
miquire :core, 'utils'
miquire :core, 'environment'
miquire :core, 'message'
miquire :core, 'configloader'
miquire :core, 'userconfig'
miquire :core, "json"

class Post < User
  include ConfigLoader

  # タイムラインのキャッシュファイルのプレフィックス。
  TIMELINE = Environment::TMPDIR + Environment::ACRO + '_timeline_cache'

  # リクエストをリトライする回数。
  TRY_LIMIT = 100

  @@threads = []
  @@xml_lock = Mutex.new
  @@auth_confirm_func = lambda{ nil }

  def initialize(check=false)
    @scaned_events = []
    @code = nil
    @twitter = Twitter.new(UserConfig[:twitter_idname], UserConfig[:twitter_password]){
      user, pass = self.auth_confirm_func.call(self)
      if user
        UserConfig[:twitter_idname] = user
        UserConfig[:twitter_password] = pass
      end
      [user, pass]
    }
    super()
  end

  def user()
    UserConfig[:twitter_idname]
  end

  def twitter
    @twitter
  end

  def auth_confirm_func
    return @@auth_confirm_func
  end

  def auth_confirm_func=(val)
    return @@auth_confirm_func = val
  end

  # twitterのタイムラインを見に行く
  def scan_data(kind, args)
    result = nil
    tl = twitter.__send__(kind, args)
    if tl.is_a?(Net::HTTPResponse) then
      case(tl.code)
      when '200':
          result = tl.body
      when '400':
          limit, remain, reset = twitter.api_remain
          Plugin::Ring::call(nil, :apilimit, self, reset) if(@code != tl.code)
      else
          Plugin::Ring::call(nil, :apifail, self, tl.code) if(@code != tl.code)
      end
      @code = tl.code
    else
      Plugin::Ring::call(nil, :apifail, self, tl.code)
    end
    return result
  end

  def scan(kind=:friends_timeline, args={})
    event_canceling = false
    if not(@scaned_events.include?(kind.to_sym)) and not(Environment::NeverRetrieveOverlappedMumble) then
      event_canceling = true
    elsif not(args[:no_auto_since_id]) and not(UserConfig[:anti_retrieve_fail]) then
      args[:since_id] = at(kind.to_s + "_lastid")
    end
    args.delete(:no_auto_since_id)
    result = parse_json(scan_data(kind, args), kind)
    if(result) then
      @scaned_events << kind.to_sym if(event_canceling)
      return result.reverse
    end
  end

  def rule(kind, prop)
    timeline_parser = {
      :hasmany => true,
      :class => Message,
      :proc => {
        :id => 'id',
        :message => 'text',
        :created => lambda{ |msg| Time.parse(msg['created_at']) },
        :reciver => 'in_reply_to_user_id',
        :replyto => 'in_reply_to_status_id',
        :favorited => 'favorited',
        :user => lambda{ |msg|
          Hash[:id, msg['user']['id'],
               :idname, msg['user']['screen_name'],
               :name, msg['user']['name'],
               :profile_image_url, msg['user']['profile_image_url']]
        }
      }
    }
    followers_perser = {
      :hasmany => true,
      :class => User,
      :proc => {
        :id => 'id',
        :name => 'name',
        :idname => 'screen_name',
        :profile_image_url => 'profile_image_url',
      }
    }
    unimessage_parser = timeline_parser.clone
    unimessage_parser[:hasmany] = false
    { :friends_timeline => timeline_parser,
      :replies => timeline_parser,
      :followers => followers_perser,
      :favorite => unimessage_parser,
      :unfavorite => unimessage_parser,
      :status_show => unimessage_parser,
    }[kind.to_sym][prop.to_sym]
  end

  def parse_json(json, cache='friends_timeline')
    if json then
      result = nil
      ti = nil
      begin
        tl = JSON.parse(json)
      rescue JSON::ParserError
        return nil
      end
      tl = [tl] if not self.rule(cache, :hasmany)
      result = tl.map{ |msg|
        param = Hash[*self.rule(cache, :proc).map { |key, proc|
                       result = nil
                       if(proc.is_a? Proc) then
                         result = proc.call(msg)
                       else
                         result = msg[proc]
                         result = entity_unescape(result) if(result.is_a?(String))
                       end
                       [key, result]
                     }.flatten].update({ :post => self, :xml => msg.to_s })
        self.rule(cache, :class).new(param)
      }
      store(cache.to_s + "_lastid", result.first['id']) if result.first
      return result
    end
  end

  def parse_xml(xml, cache='friends_timeline')
    if xml then
      result = nil
      @@xml_lock.synchronize{
        if xml.is_a?(REXML::Document) then
          result = xml.root.get_elements(self.rule(cache, :apiroot))
        else
          tl = REXML::Document.new xml
          result = tl.root.get_elements(self.rule(cache, :apiroot))
          store(cache.to_s + "_lastid", result.first.get_text('id').value) if result.first
        end
        result = result.map{ |msg|
          param = Hash[*self.rule(cache, :proc).map { |key, proc|
                         result = nil
                         if(proc.is_a? Proc) then
                           result = proc.call(msg)
                         else
                           val = msg.get_text(proc.to_s)
                           if(val) then
                             result = entity_unescape(val.value)
                           else
                             result = nil
                           end
                         end
                         [key, result]
                       }.flatten].update({ :post => self, :xml => msg.to_s })
          self.rule(cache, :class).new(param)
        }
      }
      return result
    end
  end


  # ポストキューにポストを格納する
  def post(message, &proc)
    if $quiet then
      notice "post:#{message.inspect}"
      notice 'Actually, this post does not send.'
    else
      self._post(message) {|event, message|
        if(block_given?) then
          yield(event, message)
        end
        if(event == :try)
          twitter.update(message)
        elsif(event == :success) then
          Delayer.new{|m| Plugin::Ring.fire(:update, [self, m]) }.args(message)
        end
      }
    end
  end

  def follow(user)
    if $quiet then
      notice "follow:#{user.inspect}"
      notice 'Actually, this post does not send.'
    else
      self._post(user) {|event, user|
        if(event == :try) then
          twitter.follow(user)
        end }
    end
  end

  def favorite(message, fav)
    if $quiet then
      notice "fav:#{message.inspect}"
      notice 'Actually, this post does not send.'
    else
      self._post(message) {|event, msg|
        if(event == :try)
          if(fav) then
            twitter.favorite(msg[:id])
          else
            twitter.unfavorite(msg[:id])
          end
        end
      }
    end
  end

  def _post(message)
    # @@threads <<
    Thread.new(message){ |message|
      yield(:start, nil)
      count = 1
      result = begin
        loop{
          notice "post:try:#{count}:#{message.inspect}"
          result = yield(:try, message)
          if result.is_a?(Net::HTTPResponse) and
              not(result.is_a?(Net::HTTPBadGateway)) and
              result.code == '200'
          then
            notice "post:success:#{count}:#{message.inspect}"
            receive = parse_json(result.body, :status_show).first
            if receive then
              yield(:success, receive)
              break receive
            end
          end
          notice "post:fail:#{count}:#{message.inspect}"
          notice "post:fail:#{count}:retry #{count} seconds after"
          yield(:retry, result)
          sleep(count)
          count += 1
        }
      rescue => err
        yield(:err, err)
        yield(:fail, err)
        raise err
      end
      yield(:exit, nil)
      result
    }
    # @@threads.reject!{ |thread|
    #   thread.join(1)
    # }
  end

end
