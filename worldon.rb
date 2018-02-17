# -*- coding: utf-8 -*-

module Plugin::Worldon
  PM = Plugin::Worldon
  CLIENT_NAME = 'mikutter Worldon'
  WEB_SITE = 'https://github.com/cobodo/mikutter-worldon'
end

Plugin.create(:worldon) do
  PM = Plugin::Worldon
end

require_relative 'api'
require_relative 'model/model'
#require_relative 'stream'
require_relative 'spell'
require_relative 'setting'
require_relative 'subparts_visibility'

require_relative 'sse_client'
require_relative 'sse_stream'

Plugin.create(:worldon) do
  defimageopener('Mastodon添付画像', %r<\Ahttps?://[^/]+/media/[0-9A-Za-z_-]+\Z>) do |url|
    open(url)
  end

  defevent :worldon_appear_toots, prototype: [[PM::Status]]

  filter_extract_datasources do |dss|
    datasources = { worldon_appear_toots: "受信したすべてのトゥート(Worldon)" }
    [datasources.merge(dss)]
  end

  on_worldon_appear_toots do |statuses|
    Plugin.call(:extract_receive_message, :worldon_appear_toots, statuses)
  end

  # 起動時
  Thread.new {
    Plugin.call(:worldon_restart_all_stream)
  }


  # world系

  defevent :worldon_worlds, prototype: [NilClass]

  # すべてのworldon worldを返す
  filter_worldon_worlds do
    [Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.select{|world|
      world.class.slug == :worldon_for_mastodon
    }.to_a]
  end

  defevent :current_worldon, prototype: [NilClass]

  # world_currentがworldonならそれを、そうでなければ適当に探す。
  filter_current_worldon do
    world, = Plugin.filtering(:world_current, nil)
    if world.class.slug != :worldon_for_mastodon
      worlds, = Plugin.filter(:worldon_worlds, nil)
      world = worlds.first
    end
    [world]
  end

  on_userconfig_modify do |key, value|
    if key == :worldon_enable_streaming
      Plugin.call(:worldon_restart_all_stream)
    end
  end

  # 別プラグインからインスタンスを追加してストリームを開始する例
  # domain = 'friends.nico'
  # instance, = Plugin.filtering(:worldon_add_instance, domain)
  # Plugin.call(:worldon_instance_restart_stream, instance.domain) if instance
  filter_worldon_add_instance do |domain|
    [PM::Instance.add(domain)]
  end

  # インスタンス編集
  on_worldon_instance_update do |domain|
    instance = PM::Instance.load(domain)
    next if instance.nil? # 既存にない

    Plugin.call(:worldon_instance_restart_stream, domain)
  end

  # インスタンス削除
  on_worldon_instance_delete do |domain|
    Plugin.call(:worldon_remove_instance_stream, domain)
    if UserConfig[:worldon_instances].has_key?(domain)
      config = UserConfig[:worldon_instances].dup
      config.delete(domain)
      UserConfig[:worldon_instances] = config
    end
  end

  # world追加
  on_world_create do |world|
    if world.class.slug == :worldon_for_mastodon
      Delayer.new {
        Plugin.call(:worldon_instance_create_or_update, world.domain, true)
        Plugin.call(:worldon_init_auth_stream, world)
      }
    end
  end

  # world削除
  on_world_destroy do |world|
    if world.class.slug == :worldon_for_mastodon
      Delayer.new {
        worlds = Plugin.filtering(:worldon_worlds, nil).first
        # 他のworldで使わなくなったものは削除してしまう。
        # filter_worldsから削除されるのはココと同様にon_world_destroyのタイミングらしいので、
        # この時点では削除済みである保証はなく、そのためworld.slugで判定する必要がある（はず）。
        unless worlds.any?{|w| w.slug != world.slug && w.domain != world.domain }
          Plugin.call(:worldon_instance_delete, world.domain)
        end
        Plugin.call(:worldon_remove_auth_stream, world)
      }
    end
  end

  # world追加時用
  on_worldon_instance_create_or_update do |domain|
    instance = PM::Instance.load(domain)
    if instance.nil?
      instance, = Plugin.filtering(:worldon_add_instance, domain)
    end
    next if instance.nil? # 既存にない＆接続失敗

    Plugin.call(:worldon_instance_restart_stream, domain)
  end

  # world作成
  world_setting(:worldon, _('Mastodonアカウント(Worldon)')) do
    error_msg = nil
    while true
      if error_msg.is_a? String
        label error_msg
      end
      input 'インスタンスのドメイン', :domain

      result = await_input
      domain = result[:domain]

      instance = PM::Instance.load(domain)
      if instance.nil?
        # 既存にないので追加
        instance, = Plugin.filtering(:worldon_add_instance, domain)
        if instance.nil?
          # 追加失敗
          error_msg = "#{domain} インスタンスへの接続に失敗しました。やり直してください。"
          next
        end
      end

      break
    end

    label 'Webページにアクセスして表示された認証コードを入力して、次へボタンを押してください。'
    link instance.authorize_url
    input '認証コード', :authorization_code
    result = await_input
    resp = PM::API.call(:post, domain, '/oauth/token',
                                     client_id: instance.client_key,
                                     client_secret: instance.client_secret,
                                     grant_type: 'authorization_code',
                                     redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
                                     code: result[:authorization_code]
                                    )
    token = resp[:access_token]

    resp = PM::API.call(:get, domain, '/api/v1/accounts/verify_credentials', token)
    if resp.has_key?(:error)
      Deferred.fail(resp[:error])
    end

    screen_name = resp[:acct] + '@' + domain
    resp[:acct] = screen_name
    account = PM::Account.new(resp)
    world = PM::World.new(
      id: screen_name,
      slug: :"worldon:#{screen_name}",
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
