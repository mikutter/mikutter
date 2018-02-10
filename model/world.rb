module Plugin::Worldon
  class World < Diva::Model
    register :worldon_for_mastodon, name: "Mastodonアカウント(Worldon)"

    field.string :id, required: true
    field.string :slug, required: true
    alias_method :name, :slug
    field.string :domain, required: true
    field.string :access_token, required: true
    field.has :account, Account, required: true

    alias_method :user_obj, :account

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
        "worldon-#{slug}-home".to_sym
      when :list
        # リストTL
        "worldon-#{slug}-list-#{n}".to_sym
      else
        "worldon-#{slug}-#{type.to_s}".to_sym
      end
    end

    def get_lists!
      @lists ||= API.call(:get, domain, '/api/v1/lists', access_token)
      @lists
    end

    def lists
      @lists
    end

    def update_mutes!
      mutes = PM::API.call(:get, domain, '/api/v1/mutes', access_token, limit: 80)
      since_id = nil
      while mutes.is_a? Hash
        arr = mutes
        if mutes.is_a? Hash
          arr = mutes[:array]
        end
        Status.add_mutes(arr)
        if mutes.is_a? Array || mutes[:__Link__].nil? || mutes[:__Link__][:prev].nil?
          return
        end
        url = mutes[:__Link__][:prev]
        opts = URI.decode_www_form(url.query).to_h.map{|k,v| [k.to_sym, v] }.to_h
        return if opts[:since_id].to_i == since_id
        since_id = opts[:since_id].to_i

        sleep 1
        mutes = PM::API.call(:get, domain, '/api/v1/mutes', access_token, opts)
      end
    end

    # 投稿する
    # opts[:in_reply_to_id] Integer 返信先Statusの（ローカル）ID
    # opts[:media_ids] Array 添付画像IDの配列（最大4）
    # opts[:sensitive] True | False NSFWフラグの明示的な指定
    # opts[:spoiler_text] String ContentWarning用のコメント
    # opts[:visibility] String 公開範囲。 "direct", "private", "unlisted", "public" のいずれか。
    def post(content, **opts)
      opts[:status] = content
      API.call(:post, domain, '/api/v1/statuses', access_token, opts)
    end

    def do_reblog(status)
      # TODO: guiなどの他plugin向け通知イベントの調査
      status_id = PM::API.get_local_status_id(self, status.actual_status)
      if status_id.nil?
        error 'cannot get local status id'
        return nil
      end

      new_status_hash = PM::API.call(:post, domain, '/api/v1/statuses/' + status_id.to_s + '/reblog', access_token)
      if new_status_hash.nil? || new_status_hash.has_key?(:error)
        error 'failed reblog request'
        pp new_status_hash
        return nil
      end

      new_status = PM::Status.build(domain, [new_status_hash]).first
      status.actual_status.reblogged = true
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
          pp e
          promise.fail(e)
        end
      end
      promise
    end
  end
end
