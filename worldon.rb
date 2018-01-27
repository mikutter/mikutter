# -*- coding: utf-8 -*-

require_relative 'model'
require_relative 'api'
require_relative 'instance'
require_relative 'stream'

module Plugin::Worldon
  CLIENT_NAME = 'mikutter Worldon'
  WEB_SITE = 'https://github.com/cobodo/mikutter-worldon'
end

Plugin.create(:worldon) do
  keys = at(:instances)
  if keys.nil?
    keys = Hash.new
    store(:instances, keys)
  end

  def init_instance_stream (domain)
    instance = Plugin::Worldon::Instance.load(domain)

    notice "[worldon] get initial ftl/ltl for #{domain}"
    ftl_slug = Plugin::Worldon::Instance.datasource_slug(domain, :federated)
    ltl_slug = Plugin::Worldon::Instance.datasource_slug(domain, :local)
    ftl = Plugin::Worldon::Status.build Plugin::Worldon::API.call(:get, domain, '/api/v1/timelines/public', limit: 40)
    ltl = Plugin::Worldon::Status.build Plugin::Worldon::API.call(:get, domain, '/api/v1/timelines/public', local: 1, limit: 40)
    Plugin.call :extract_receive_message, ftl_slug, ftl
    Plugin.call :extract_receive_message, ltl_slug, ltl

    Plugin::Worldon::Stream.start(domain, 'public', ftl_slug)
    Plugin::Worldon::Stream.start(domain, 'public:local', ltl_slug)
  end

  defevent :worldon_start_stream, prototype: [String, String, String, String, Integer]

  on_worldon_start_stream do |domain, type, slug, token, list_id|
    Plugin::Worldon::Stream.start(domain, type, slug, token, list_id)
    opts = { limit: 40 }
    case type
    when 'user'
      rest_type = 'home'
    when 'public'
      rest_type = 'public'
    when 'public:local'
      rest_type = 'public'
      opts[:local] = 1
    when 'list'
      rest_type = 'list/' + list_id.to_s
    end
    tl = Plugin::Worldon::Status.build Plugin::Worldon::API.call(:get, domain, '/api/v1/timelines/' + type, token, opts)
    Plugin.call :extract_receive_message, slug, tl
  end

  def init_auth_stream (world)
    filter_extract_datasources do |dss|
      notice '[worldon] preparing worldon datasources'
      instance = Plugin::Worldon::Instance.load(world.domain)
      datasources = { world.datasource_slug(:home) => "#{world.slug}(Worldon)/ホームタイムライン" }
      lists = world.get_lists
      if lists.is_a? Array
        lists.each do |l|
          slug = world.datasource_slug(:list, l[:id])
          datasources[slug] = "#{world.slug}(Worldon)/リスト/#{l[:title]}"
        end
      else
        warn '[worldon] failed to get lists:' + lists['error']
      end
      [datasources.merge(dss)]
    end

    if UserConfig[:realtime_rewind]
      Plugin.call(:worldon_start_stream, world.domain, 'user', world.datasource_slug(:home), world.access_token)
      Plugin.call(:worldon_start_stream, world.domain, 'user:notification', world.datasource_slug(:notification), world.access_token)

      lists = world.get_lists
      if lists.is_a? Array
        lists.each do |l|
          id = l[:id].to_i
          slug = world.datasource_slug(:list, id)
          Plugin.call(:worldon_start_stream, world.domain, 'list', world.datasource_slug(:list, id), world.access_token, id)
        end
      end
    end
  end

  onunload do
    Plugin::Worldon::Stream.killall
  end

  Delayer.new {
    worlds = Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.select do |world|
      world.class.slug == :worldon_for_mastodon
    end

    worlds.each do |world|
      pp world
      init_auth_stream(world)
    end

    worlds.map{|world|
      world.domain
    }.to_a.uniq.each{|domain|
      Plugin::Worldon::Instance.add_datasources(domain)
      init_instance_stream(domain)
    }
  }

  on_world_create do |world|
    if world.class.slug == :worldon_for_mastodon
      init_auth_stream(world)
    end
  end

  world_setting(:worldon, _('Mastodonアカウント(Worldon)')) do
    input 'インスタンスのドメイン', :domain

    result = await_input
    domain = result[:domain]

    instance = Plugin::Worldon::Instance.load(domain)

    label 'Webページにアクセスして表示された認証コードを入力して、次へボタンを押してください。'
    link instance.authorize_url
    input '認証コード', :authorization_code
    result = await_input
    resp = Plugin::Worldon::API.call(:post, domain, '/oauth/token',
                                     client_id: instance.client_key,
                                     client_secret: instance.client_secret,
                                     grant_type: 'authorization_code',
                                     redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
                                     code: result[:authorization_code]
                                    )
    token = resp[:access_token]

    resp = Plugin::Worldon::API.call(:get, domain, '/api/v1/accounts/verify_credentials', token)
    if resp.has_key?(:error)
      Deferred.fail(resp[:error])
    end
    screen_name = resp[:acct] + '@' + domain
    resp[:acct] = screen_name
    account = Plugin::Worldon::Account.new_ifnecessary(resp)
    world = Plugin::Worldon::World.new(
      id: screen_name,
      slug: screen_name,
      domain: domain,
      access_token: token,
      account: account
    )
    notice "added new Worldon account #{screen_name}"

    label '認証に成功しました。このアカウントを追加しますか？'
    label('アカウント名：' + screen_name)
    label('ユーザー名：' + resp[:display_name])
    world
  end
end
