# -*- coding: utf-8 -*-
require 'pp'

module Plugin::Mastodon
  PM = Plugin::Mastodon
  CLIENT_NAME = 'mikutter Mastodon'
  WEB_SITE = 'https://mikutter.hachune.net/'
end

require_relative 'util'
require_relative 'api'
require_relative 'parser'
require_relative 'model/model'
require_relative 'patch'
require_relative 'spell'
require_relative 'setting'
require_relative 'subparts_status_info'
require_relative 'extractcondition'
require_relative 'sse_client'
require_relative 'sse_stream'
require_relative 'rest'
require_relative 'score'

Plugin.create(:mastodon) do
  pm = Plugin::Mastodon

  defimageopener('Mastodon添付画像', %r<\Ahttps?://[^/]+/system/media_attachments/files/[0-9]{3}/[0-9]{3}/[0-9]{3}/\w+/\w+\.\w+(?:\?\d+)?\Z>) do |url|
    open(url)
  end

  defimageopener('Mastodon添付画像（短縮）', %r<\Ahttps?://[^/]+/media/[0-9A-Za-z_-]+(?:\?\d+)?\Z>) do |url|
    open(url)
  end

  defimageopener('Mastodon添付画像(proxy)', %r<\Ahttps?://[^/]+/media_proxy/[0-9]+/(?:original|small)\z>) do |url|
    open(url)
  end

  defevent :mastodon_appear_toots, prototype: [[pm::Status]]

  filter_extract_datasources do |dss|
    datasources = { mastodon_appear_toots: "受信したすべてのトゥート(Mastodon)" }
    [datasources.merge(dss)]
  end

  on_mastodon_appear_toots do |statuses|
    Plugin.call(:extract_receive_message, :mastodon_appear_toots, statuses)
  end

  followings_updater = Proc.new do
    activity(:system, "自分のプロフィールやフォロー関係を取得しています...")
    Plugin.filtering(:mastodon_worlds, nil).first.to_a.each do |world|
      world.update_account
      world.blocks!
      world.followings(cache: false).next do |followings|
        activity(:system, "自分のプロフィールやフォロー関係の取得が完了しました(#{world.account.acct})")
      end
      Plugin.call(:world_modify, world)
    end

    Reserver.new(10 * HYDE, &followings_updater) # 26分ごとにプロフィールとフォロー一覧を更新する
  end

  # 起動時
  Delayer.new {
    followings_updater.call
  }


  # world系

  defevent :mastodon_worlds, prototype: [NilClass]

  # すべてのmastodon worldを返す
  filter_mastodon_worlds do
    [Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.select{|world|
      world.class.slug == :mastodon
    }.to_a]
  end

  defevent :mastodon_current, prototype: [NilClass]

  # world_currentがmastodonならそれを、そうでなければ適当に探す。
  filter_mastodon_current do
    world, = Plugin.filtering(:world_current, nil)
    unless mastodon?(world)
      worlds, = Plugin.filtering(:mastodon_worlds, nil)
      world = worlds.first
    end
    [world]
  end

  on_userconfig_modify do |key, value|
    if [:mastodon_enable_streaming, :extract_tabs].include?(key)
      Plugin.call(:mastodon_restart_all_streams)
    end
  end

  # 別プラグインからサーバーを追加してストリームを開始する例
  # domain = 'friends.nico'
  # instance, = Plugin.filtering(:mastodon_add_instance, domain)
  # Plugin.call(:mastodon_restart_instance_stream, instance.domain) if instance
  filter_mastodon_add_instance do |domain|
    [pm::Instance.add(domain)]
  end

  # サーバー編集
  on_mastodon_update_instance do |domain|
    Thread.new {
      instance = pm::Instance.load(domain)
      next if instance.nil? # 既存にない

      Plugin.call(:mastodon_restart_instance_stream, domain)
    }
  end

  # サーバー削除
  on_mastodon_delete_instance do |domain|
    Plugin.call(:mastodon_remove_instance_stream, domain)
    if UserConfig[:mastodon_instances].has_key?(domain)
      config = UserConfig[:mastodon_instances].dup
      config.delete(domain)
      UserConfig[:mastodon_instances] = config
    end
  end

  # world追加時用
  on_mastodon_create_or_update_instance do |domain|
    Thread.new {
      instance = pm::Instance.load(domain)
      if instance.nil?
        instance, = Plugin.filtering(:mastodon_add_instance, domain)
      end
      next if instance.nil? # 既存にない＆接続失敗

      Plugin.call(:mastodon_restart_instance_stream, domain)
    }
  end

  # world追加
  on_world_create do |world|
    if world.class.slug == :mastodon
      Delayer.new {
        Plugin.call(:mastodon_create_or_update_instance, world.domain, true)
      }
    end
  end

  # world削除
  on_world_destroy do |world|
    if world.class.slug == :mastodon
      Delayer.new {
        worlds = Plugin.filtering(:mastodon_worlds, nil).first
        # 他のworldで使わなくなったものは削除してしまう。
        # filter_worldsから削除されるのはココと同様にon_world_destroyのタイミングらしいので、
        # この時点では削除済みである保証はなく、そのためworld.slugで判定する必要がある（はず）。
        unless worlds.any?{|w| w.slug != world.slug && w.domain != world.domain }
          Plugin.call(:mastodon_delete_instance, world.domain)
        end
        Plugin.call(:mastodon_remove_auth_stream, world)
      }
    end
  end

  # world作成
  world_setting(:mastodon, _('Mastodon(Mastodon)')) do
    error_msg = nil
    while true
      if error_msg.is_a? String
        label error_msg
      end
      input 'サーバーのドメイン', :domain

      result = await_input
      domain = result[:domain]

      instance = pm::Instance.load(domain)
      if instance.nil?
        # 既存にないので追加
        instance, = Plugin.filtering(:mastodon_add_instance, domain)
        if instance.nil?
          # 追加失敗
          error_msg = "#{domain} サーバーへの接続に失敗しました。やり直してください。"
          next
        end
      end

      break
    end

    error_msg = nil
    while true
      if error_msg.is_a? String
        label error_msg
      end
      label 'Webページにアクセスして表示された認証コードを入力して、次へボタンを押してください。'
      link instance.authorize_url
      puts instance.authorize_url # ブラウザで開けない時のため
      $stdout.flush
      input '認証コード', :authorization_code
      if error_msg.is_a? String
        input 'アクセストークンがあれば入力してください', :access_token
      end
      result = await_input
      if result[:authorization_code]
        result[:authorization_code].strip!
      end
      if result[:access_token]
        result[:access_token].strip!
      end

      if ((result[:authorization_code].nil? || result[:authorization_code].empty?) && (result[:access_token].nil? || result[:access_token].empty?))
        error_msg = "認証コードを入力してください"
        next
      end

      break
    end

    if result[:authorization_code]
      resp = pm::API.call(:post, domain, '/oauth/token',
                                       client_id: instance.client_key,
                                       client_secret: instance.client_secret,
                                       grant_type: 'authorization_code',
                                       redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
                                       code: result[:authorization_code]
                                      )
      if resp.nil? || resp.value.has_key?(:error)
        label "認証に失敗しました#{resp && resp[:error] ? "：#{resp[:error]}" : ''}"
        await_input
        raise (resp.nil? ? 'error has occurred at /oauth/token' : resp[:error])
      end
      token = resp[:access_token]
    else
      token = result[:access_token]
    end

    resp = pm::API.call(:get, domain, '/api/v1/accounts/verify_credentials', token)
    if resp.nil? || resp.value.has_key?(:error)
      label "アカウント情報の取得に失敗しました#{resp && resp[:error] ? "：#{resp[:error]}" : ''}"
      raise (resp.nil? ? 'error has occurred at verify_credentials' : resp[:error])
    end

    screen_name = resp[:acct] + '@' + domain
    resp[:acct] = screen_name
    account = pm::Account.new(resp.value)
    world = pm::World.new(
      id: screen_name,
      slug: :"mastodon:#{screen_name}",
      domain: domain,
      access_token: token,
      account: account
    )
    world.update_mutes!

    label '認証に成功しました。このアカウントを追加しますか？'
    label('アカウント名：' + screen_name)
    label('ユーザー名：' + resp[:display_name])
    world
  end
end
