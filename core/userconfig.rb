# -*- coding: utf-8 -*-
#
# UserConfig
#

# プログラムから動的に変更される設定
# プラグインの設定ではないので注意

miquire :core, 'utils'
miquire :core, 'configloader'

require 'singleton'
require 'fileutils'
require 'gtk2'

class UserConfig
  include ConfigLoader
  include Singleton

  #
  # 予約された設定一覧
  #

  @@defaults = {
    :retrieve_interval_friendtl => 1,   # TLを更新する間隔(int)
    :retrieve_interval_mention => 20,   # Replyを更新する間隔(int)
    :retrieve_interval_search => 60,    # 検索を更新する間隔(int)
    :retrieve_interval_followed => 60,  # followerを更新する間隔(int)

    :retrieve_count_friendtl => MIKU,   # TLを取得する数(int)
    :retrieve_count_mention => MIKU,    # Replyを取得する数(int)
    :retrieve_count_followed => MIKU,   # followerを取得する数(int)

    # デフォルトのフッダ
    :footer => "",

    # リプライ元を常に取得する
    :retrieve_force_mumbleparent => true,

    # 遅延対策
    :anti_retrieve_fail => false,

    # つぶやきを投稿するキー
    :mumble_post_key => defined?(Gdk) ? [65293, Gdk::Window::CONTROL_MASK] : nil,

    # 通知を表示しておく秒数
    :notify_expire_time => 10,

    # 常にURLを短縮
    :shrinkurl_always => true,

    :biyly_user => '',
    :bitly_apikey => '',

    :mumble_basic_font => 'Sans 10',
    :mumble_basic_color => [0, 0, 0],
    :mumble_reply_font => 'Sans 8',
    :mumble_reply_color => [255*0x66, 255*0x66, 255*0x66],

    :mumble_basic_bg => [65535, 65535, 65535],
    :mumble_reply_bg => [65535, 255*222, 255*222],
    :mumble_self_bg => [65535, 65535, 255*222],
    :mumble_selected_bg => [65535, 255*222, 65535],

  }

  @@watcher = Hash.new{ [] }
  @@watcher_id = Hash.new
  @@watcher_id_count = 0

  # self::[key]
  # 設定名keyにたいする値を取り出す
  # 値が設定されていない場合、nilを返す。
  def self.[](key)
    return UserConfig.instance.at(key, @@defaults[key.to_sym])
  end

  # self::[key] = value
  # 設定名keyに値valueを関連付ける
  def self.[]=(key, val)
    atomic{
      if not(@@watcher[key].empty?) then
        before_val = UserConfig.instance.at(key, @@defaults[key.to_sym])
        @@watcher[key].each{ |id|
          proc = nil
          atomic{
            if @@watcher_id.has_key?(id) then
              proc = @@watcher_id[id]
            else
              @@watcher[key].delete(id)
            end
          }
          proc.call(key, val, before_val, id) if proc
        }
      end
    }
    UserConfig.instance.store(key, val)
  end

  def self.connect(key, &watcher)
    atomic{
      id = @@watcher_id_count
      @@watcher_id_count += 1
      @@watcher[key] << id
      @@watcher_id[id] = watcher
      id
    }
  end

  def self.disconnect(id)
    atomic{
      @@watcher_id.delete(id)
    }
  end

end
