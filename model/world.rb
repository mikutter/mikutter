# coding: utf-8
module Plugin::Worldon
  class World < Diva::Model
    extend Memoist

    register :worldon, name: "Mastodon(Worldon)"

    field.string :id, required: true
    field.string :slug, required: true
    alias :name :slug
    field.string :domain, required: true
    field.string :access_token, required: true
    field.has :account, Account, required: true

    alias :user_obj :account

    attr_reader :lists

    memoize def path
      "/#{account.acct.split('@').reverse.join('/')}"
    end

    def inspect
      "worldon-world(#{account.acct})"
    end

    def icon
      account.icon
    end

    def title
      account.title
    end

    def datasource_slug(type, n = nil)
      case type
      when :home
        # ホームTL
        "worldon-#{account.acct}-home".to_sym
      when :list
        # リストTL
        "worldon-#{account.acct}-list-#{n}".to_sym
      else
        "worldon-#{account.acct}-#{type.to_s}".to_sym
      end
    end

    def get_lists!
      return @lists if @lists

      lists = API.call(:get, domain, '/api/v1/lists', access_token)
      if lists.nil?
        warn "[worldon] failed to get lists"
      elsif lists.value.is_a? Array
        @lists = lists.value
      elsif lists.value.is_a?(Hash) && lists['error']
        warn "[worldon] failed to get lists: #{lists['error'].to_s}"
      end
    end

    def update_mutes!
      params = { limit: 80 }
      since_id = nil
      Status.clear_mutes
      while mutes = PM::API.call(:get, domain, '/api/v1/mutes', access_token, **params)
        Status.add_mutes(mutes.value)
        if mutes.header.nil? || mutes.header[:prev].nil?
          return
        end
        url = mutes.header[:prev]
        params = URI.decode_www_form(url.query).to_h.map{|k,v| [k.to_sym, v] }.to_h
        return if params[:since_id].to_i == since_id
        since_id = params[:since_id].to_i

        sleep 1
      end
    end

    # 投稿する
    # opts[:in_reply_to_id] Integer 返信先Statusの（ローカル）ID
    # opts[:media_ids] Array 添付画像IDの配列（最大4）
    # opts[:sensitive] True | False NSFWフラグの明示的な指定
    # opts[:spoiler_text] String ContentWarning用のコメント
    # opts[:visibility] String 公開範囲。 "direct", "private", "unlisted", "public" のいずれか。
    def post(content, **params)
      params[:status] = content
      API.call(:post, domain, '/api/v1/statuses', access_token, **params)
    end

    def do_reblog(status)
      status_id = PM::API.get_local_status_id(self, status.actual_status)
      if status_id.nil?
        error 'cannot get local status id'
        return nil
      end

      new_status_hash = PM::API.call(:post, domain, '/api/v1/statuses/' + status_id.to_s + '/reblog', access_token)
      if new_status_hash.nil? || new_status_hash.value.has_key?(:error)
        error 'failed reblog request'
        pp new_status_hash if Mopt.error_level >= 1
        $stdout.flush
        return nil
      end

      new_status = PM::Status.build(domain, [new_status_hash.value]).first
      return if new_status.nil?

      status.actual_status.reblogged = true
      status.reblog_status_uris << { uri: new_status.original_uri, acct: account.acct }
      status.reblog_status_uris.uniq!
      Plugin.call(:retweet, [new_status])

      status_world = status.from_me_world
      if status_world
        Plugin.call(:mention, status_world, [new_status])
      end
    end

    def reblog(status)
      promise = Delayer::Deferred.new(true)
      Thread.new do
        begin
          new_status = do_reblog(status)
          if new_status.is_a? Status
            promise.call(new_status)
          else
            promise.fail(new_status)
          end
        rescue Exception => e
          pp e if Mopt.error_level >= 2 # warn
          $stdout.flush
          promise.fail(e)
        end
      end
      promise
    end

    def get_accounts!(type)
      promise = Delayer::Deferred.new(true)
      Thread.new do
        begin
          accounts = []
          params = {
            limit: 80
          }
          API.all_with_world(self, :get, "/api/v1/accounts/#{account.id}/#{type}", **params) do |hash|
            accounts << hash
          end
          promise.call(accounts.map {|hash| Account.new hash })
        rescue Exception => e
          pp e if Mopt.error_level >= 2 # warn
          $stdout.flush
          promise.fail("failed to get #{type}")
        end
      end
      promise
    end

    def following?(acct)
      acct = acct.acct if acct.is_a?(Account)
      @followings&.any? { |account| account.acct == acct }
    end

    def followings(cache: true, **opts)
      promise = Delayer::Deferred.new(true)
      Thread.new do
        next promise.call(@followings) if cache && @followings
        get_accounts!('following').next do |accounts|
          @followings = accounts
        end
      end
      promise
    end

    def followers(cache: true, **opts)
      promise = Delayer::Deferred.new(true)
      Thread.new do
        next promise.call(@followers) if cache && @followers
        get_accounts!('followers').next do |accounts|
          @followers = accounts
        end
      end
      promise
    end

    def blocks
      @blocks ||= []
    end

    def blocks!
      promise = Delayer::Deferred.new(true)
      Thread.new do
        begin
          accounts = []
          params = {
            limit: 80
          }
          API.all_with_world(self, :get, "/api/v1/blocks", **params) do |hash|
            accounts << hash
          end
          @blocks = accounts.map { |hash| Account.new hash }
          promise.call(@blocks)
        rescue Exception => e
          pp e if Mopt.error_level >= 2 # warn
          $stdout.flush
          promise.fail('failed to get blocks')
        end
      end
      promise
    end

    def block?(acct)
      @blocks.any? { |acc| acc.acct == acct }
    end

    def account_action(account, type)
      account_id = PM::API.get_local_account_id(self, account)
      PM::API.call(:post, domain, "/api/v1/accounts/#{account_id}/#{type}", access_token)
    end

    def follow(account)
      ret = account_action(account, "follow")

      if ret
        @followings << account
        followings(cache: false)
      end

      ret
    end

    def unfollow(account)
      ret = account_action(account, "unfollow")

      if ret
        @followings.delete_if do |acc|
          acc.acct == account.acct
        end

        followings(cache: false)
      end

      ret
    end

    def mute(account)
      account_action(account, "mute")
      update_mutes!
    end

    def unmute(account)
      account_action(account, "unmute")
      update_mutes!
    end

    def block(account)
      account_action(account, "block")
      blocks!
    end

    def unblock(account)
      account_action(account, "unblock")
      blocks!
    end

    def pin(status)
      status_id = PM::API.get_local_status_id(self, status)
      PM::API.call(:post, domain, "/api/v1/statuses/#{status_id}/pin", access_token)
      status.pinned = true
    end

    def unpin(status)
      status_id = PM::API.get_local_status_id(self, status)
      PM::API.call(:post, domain, "/api/v1/statuses/#{status_id}/unpin", access_token)
      status.pinned = false
    end

    def report_for_spam(statuses, comment)
      account_id = PM::API.get_local_account_id(self, statuses.first.account)
      params = {
        account_id: account_id,
        status_ids: statuses.map { |status| PM::API.get_local_status_id(self, status) },
        comment: comment,
      }
      PM::API.call(:post, domain, "/api/v1/reports", access_token, **params)
    end

    def update_account
      resp = PM::API.call(:get, domain, '/api/v1/accounts/verify_credentials', access_token)
      if resp.nil? || resp.value.has_key?(:error)
        warn(resp.nil? ? 'error has occurred at verify_credentials' : resp[:error])
        return
      end

      resp[:acct] = resp[:acct] + '@' + domain
      self.account = PM::Account.new(resp.value)
    end

    def update_profile(**opts)
      params = {}
      params[:display_name] = opts[:name] if opts[:name]
      params[:note] = opts[:biography] if opts[:biography]
      params[:locked] = opts[:locked] if !opts[:locked].nil?
      params[:bot] = opts[:bot] if !opts[:bot].nil?
      ds = []
      if opts[:icon]
        if opts[:icon].is_a?(Plugin::Photo::Photo)
          ds << opts[:icon].download.next{|photo| [:avatar, photo] }
        else
          params[:avatar] = opts[:icon]
        end
      end
      if opts[:header]
        if opts[:header].is_a?(Plugin::Photo::Photo)
          ds << opts[:header].download.next{|photo| [:header, photo] }
        else
          params[:header] = opts[:header]
        end
      end
      if ds.empty?
        ds << Delayer::Deferred.new.next{ [:none, nil] }
      end
      Delayer::Deferred.when(ds).next{|vs|
        vs.each do |key, val|
          params[key] = val
        end
        new_account = PM::API.call(:patch, domain, '/api/v1/accounts/update_credentials', access_token, **params)
        if new_account.value
          self.account = PM::Account.new(new_account.value)
          Plugin.call(:world_modify, self)
        end
      }
    end
  end
end
