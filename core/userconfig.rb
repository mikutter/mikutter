# -*- coding: utf-8 -*-

require File.expand_path('utils')
miquire :core, 'configloader'

require 'singleton'
require 'fileutils'

#
#= UserConfig 動的な設定
#
#プログラムから動的に変更される設定。
#プラグインの設定ではないので注意。
class UserConfig
  include Singleton
  include ConfigLoader
  extend MonitorMixin
  #
  # 予約された設定一覧
  #

  @@defaults = {
    :retrieve_interval_friendtl => 1,   # TLを更新する間隔(int)
    :retrieve_interval_mention => 20,   # Replyを更新する間隔(int)
    :retrieve_interval_search => 60,    # 検索を更新する間隔(int)
    :retrieve_interval_followings => 60,  # followを更新する間隔(int)
    :retrieve_interval_followers => 60,  # followerを更新する間隔(int)
    :retrieve_interval_direct_messages => 20,  # DirectMessageを更新する間隔(int)
    :retrieve_interval_list_timeline => 60,    # リストの更新間隔(int)

    :retrieve_count_friendtl => 20,   # TLを取得する数(int)
    :retrieve_count_mention => 20,    # Replyを取得する数(int)
    :retrieve_count_followings => 20,   # followを取得する数(int)
    :retrieve_count_followers => 20,   # followerを取得する数(int)
    :retrieve_count_direct_messages => 200,   # followerを取得する数(int)

    :update_queue_delay => 100,
    :favorite_queue_delay => 100,
    :follow_queue_delay => 100,
    :direct_message_queue_delay => 100,

    # User Stream
    :realtime_rewind => true,
    :filter_realtime_rewind => true,

    # デフォルトのフッダ
    :footer => "",

    # リプライ元を常に取得する
    :retrieve_force_mumbleparent => true,

    # 遅延対策
    :anti_retrieve_fail => false,

    # つぶやきを投稿するキー
    :shortcutkey_keybinds => {1 => {:key => "Control + Return", :name => '投稿する', :slug => :post_it}},

    # リクエストをリトライする回数
    :message_retry_limit => 10,

    # 通知を表示しておく秒数
    :notify_expire_time => 10,

    :retweeted_by_anyone_show_timeline => true,

    :retweeted_by_anyone_age => true,

    :favorited_by_anyone_show_timeline => true,

    :favorited_by_anyone_age => true,

    # プロフィールタブの並び順
    :profile_tab_order => [:usertimeline, :aboutuser, :list],

    # 設定タブの並び順
    :tab_order_in_settings => ["基本設定", "表示", "入力", "通知", "抽出タブ", "リスト", "ショートカットキー", "アカウント情報", "プロキシ"],

    # タブの位置 [上,下,左,右]
    :tab_position => 3,

    # 常にURLを短縮して投稿
    :shrinkurl_always => false,

    # 常にURLを展開して表示
    :shrinkurl_expand => true,

    # 非公式RTにin_reply_to_statusをつける
    :legacy_retweet_act_as_reply => false,

    :bitly_user => '',
    :bitly_apikey => '',

    :mumble_basic_font => 'Sans 10',
    :mumble_basic_color => [0, 0, 0],
    :mumble_reply_font => 'Sans 8',
    :mumble_reply_color => [255*0x66, 255*0x66, 255*0x66],
    :mumble_basic_left_font => 'Sans 10',
    :mumble_basic_left_color => [0, 0, 0],
    :mumble_basic_right_font => 'Sans 10',
    :mumble_basic_right_color => [255*0x99, 255*0x99, 255*0x99],

    :mumble_basic_bg => [65535, 65535, 65535],
    :mumble_reply_bg => [65535, 255*222, 255*222],
    :mumble_self_bg => [65535, 65535, 255*222],
    :mumble_selected_bg => [255*222, 255*222, 65535],

    # 右クリックメニューの並び順
    :mumble_contextmenu_order => ['copy_selected_region',
                                  'copy_description',
                                  'reply',
                                  'reply_all',
                                  'retweet',
                                  'delete_retweet',
                                  'legacy_retweet',
                                  'favorite',
                                  'delete_favorite',
                                  'delete'],

    :subparts_order => ["Gdk::ReplyViewer", "Gdk::SubPartsFavorite", "Gdk::SubPartsRetweet"],

    :activity_mute_kind => ["error"],
    :activity_show_timeline => ["system"]

  }

  @@watcher = Hash.new{ [] }
  @@watcher_id = Hash.new
  @@watcher_id_count = 0

  # 設定名 _key_ にたいする値を取り出す
  # 値が設定されていない場合、nilを返す。
  def self.[](key)
    UserConfig.instance.at(key, @@defaults[key.to_sym])
  end

  # 設定名 _key_ に値 _value_ を関連付ける
  def self.[]=(key, val)
    watchers = synchronize{
      if not(@@watcher[key].empty?)
        before_val = UserConfig.instance.at(key, @@defaults[key.to_sym])
        @@watcher[key].map{ |id|
          proc = if @@watcher_id.has_key?(id)
                   @@watcher_id[id]
                 else
                   @@watcher[key].delete(id)
                   nil end
          lambda{ proc.call(key, val, before_val, id) } if proc } end }
    if watchers.is_a? Enumerable
      watchers.each{ |w| w.call if w } end
    UserConfig.instance.store(key, val)
  end

  # 設定名 _key_ の値が変更されたときに、ブロック _watcher_ を呼び出す。
  # watcher_idを返す。
  def self.connect(key, &watcher)
    synchronize{
      id = @@watcher_id_count
      @@watcher_id_count += 1
      @@watcher[key] = @@watcher[key].push(id)
      @@watcher_id[id] = watcher
      id
    }
  end

  # watcher idが _id_ のwatcherを削除する。
  def self.disconnect(id)
    synchronize{
      @@watcher_id.delete(id)
    }
  end

  def self.setup
    last_boot_version = UserConfig[:last_boot_version] || [0, 0, 0, 0]
    if last_boot_version < Environment::VERSION.to_a
      UserConfig[:last_boot_version] = Environment::VERSION.to_a
      if last_boot_version == [0, 0, 0, 0]
        key_add "Alt + x", "コンソールを開く", :console_open
      end
    end
  end

  def self.key_add(key, name, slug)
    type_strict key => String, name => String, slug => Symbol
    keys = UserConfig[:shortcutkey_keybinds].melt
    keys[(keys.keys.max || 0)+1] = {
      :key => key,
      :name => name,
      :slug => slug}
    UserConfig[:shortcutkey_keybinds] = keys end

  setup

end


