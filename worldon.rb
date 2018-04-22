# -*- coding: utf-8 -*-
require 'pp'

module Plugin::Worldon
  PM = Plugin::Worldon
  CLIENT_NAME = 'mikutter Worldon'
  WEB_SITE = 'https://github.com/cobodo/mikutter-worldon'
end

require_relative 'util'
require_relative 'api'
require_relative 'model/model'
require_relative 'patch'
require_relative 'spell'
require_relative 'setting'
require_relative 'subparts_visibility'
require_relative 'extractcondition'
require_relative 'sse_client'
require_relative 'sse_stream'
require_relative 'rest'
require_relative 'score'

Plugin.create(:worldon) do
  pm = Plugin::Worldon

  defimageopener('Mastodon添付画像', %r<\Ahttps?://[^/]+/media/[0-9A-Za-z_-]+\Z>) do |url|
    open(url)
  end

  defevent :worldon_appear_toots, prototype: [[pm::Status]]

  filter_extract_datasources do |dss|
    datasources = { worldon_appear_toots: "受信したすべてのトゥート(Worldon)" }
    [datasources.merge(dss)]
  end

  on_worldon_appear_toots do |statuses|
    Plugin.call(:extract_receive_message, :worldon_appear_toots, statuses)
  end

  # 起動時
  Delayer.new {
    Plugin.filtering(:worldon_worlds, nil).first.to_a.each do |world|
      world.update_account
      Plugin.call(:world_modify, world)
    end
    Plugin.call(:worldon_restart_all_stream)
  }


  # world系

  defevent :worldon_worlds, prototype: [NilClass]

  # すべてのworldon worldを返す
  filter_worldon_worlds do
    [Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.select{|world|
      world.class.slug == :worldon
    }.to_a]
  end

  defevent :worldon_current, prototype: [NilClass]

  # world_currentがworldonならそれを、そうでなければ適当に探す。
  filter_worldon_current do
    world, = Plugin.filtering(:world_current, nil)
    if world.class.slug != :worldon
      worlds, = Plugin.filtering(:worldon_worlds, nil)
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
  # Plugin.call(:worldon_restart_instance_stream, instance.domain) if instance
  filter_worldon_add_instance do |domain|
    [pm::Instance.add(domain)]
  end

  # インスタンス編集
  on_worldon_update_instance do |domain|
    Thread.new {
      instance = pm::Instance.load(domain)
      next if instance.nil? # 既存にない

      Plugin.call(:worldon_restart_instance_stream, domain)
    }
  end

  # インスタンス削除
  on_worldon_delete_instance do |domain|
    Plugin.call(:worldon_remove_instance_stream, domain)
    if UserConfig[:worldon_instances].has_key?(domain)
      config = UserConfig[:worldon_instances].dup
      config.delete(domain)
      UserConfig[:worldon_instances] = config
    end
  end

  # world追加時用
  on_worldon_create_or_update_instance do |domain|
    Thread.new {
      instance = pm::Instance.load(domain)
      if instance.nil?
        instance, = Plugin.filtering(:worldon_add_instance, domain)
      end
      next if instance.nil? # 既存にない＆接続失敗

      Plugin.call(:worldon_restart_instance_stream, domain)
    }
  end

  # world追加
  on_world_create do |world|
    if world.class.slug == :worldon
      Delayer.new {
        Plugin.call(:worldon_create_or_update_instance, world.domain, true)
        Plugin.call(:worldon_init_auth_stream, world)
      }
    end
  end

  # world削除
  on_world_destroy do |world|
    if world.class.slug == :worldon
      Delayer.new {
        worlds = Plugin.filtering(:worldon_worlds, nil).first
        # 他のworldで使わなくなったものは削除してしまう。
        # filter_worldsから削除されるのはココと同様にon_world_destroyのタイミングらしいので、
        # この時点では削除済みである保証はなく、そのためworld.slugで判定する必要がある（はず）。
        unless worlds.any?{|w| w.slug != world.slug && w.domain != world.domain }
          Plugin.call(:worldon_delete_instance, world.domain)
        end
        Plugin.call(:worldon_remove_auth_stream, world)
      }
    end
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

      instance = pm::Instance.load(domain)
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
      result = await_input

      if result[:authorization_code].nil? || result[:authorization_code].empty?
        error_msg = "認証コードを入力してください"
        next
      end

      break
    end
    resp = pm::API.call(:post, domain, '/oauth/token',
                                     client_id: instance.client_key,
                                     client_secret: instance.client_secret,
                                     grant_type: 'authorization_code',
                                     redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
                                     code: result[:authorization_code]
                                    )
    if resp.nil? || resp.has_key?(:error)
      Deferred.fail(resp.nil? ? 'error has occurred at /oauth/token' : resp[:error])
    end
    token = resp[:access_token]

    resp = pm::API.call(:get, domain, '/api/v1/accounts/verify_credentials', token)
    if resp.nil? || resp.has_key?(:error)
      Deferred.fail(resp.nil? ? 'error has occurred at verify_credentials' : resp[:error])
    end

    screen_name = resp[:acct] + '@' + domain
    resp[:acct] = screen_name
    account = pm::Account.new(resp)
    world = pm::World.new(
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
