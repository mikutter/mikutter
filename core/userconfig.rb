#
# UserConfig
#

# プログラムから動的に変更される設定
# プラグインの設定ではないので注意

miquire :core, 'utils'
miquire :core, 'configloader'

require 'singleton'
require 'fileutils'

class UserConfig
  include ConfigLoader
  include Singleton

  #
  # 予約された設定一覧
  #

  @@defaults = {
    :retrieve_interval_friendtl => 1,   # TLを更新する間隔(int)
    :retrieve_interval_mention => 20,   # Replyを更新する間隔(int)
    :retrieve_interval_followed => 60,  # followerを更新する間隔(int)

    :retrieve_count_friendtl => MIKU,   # TLを取得する数(int)
    :retrieve_count_mention => MIKU,    # Replyを取得する数(int)
    :retrieve_count_followed => MIKU,   # followerを取得する数(int)

    # つぶやきを投稿するキー
    :mumble_post_key => [65293, Gdk::Window::CONTROL_MASK],

    # 通知を表示しておく秒数
    :notify_expire_time => 10
  }

  @@watcher = Hash.new{ [] }
  @@watcher_id = Hash.new
  @@watcher_id_count = 0
  @@connect_mutex = Mutex.new

  # self::[key]
  # 設定名keyにたいする値を取り出す
  # 値が設定されていない場合、nilを返す。
  def self.[](key)
    return UserConfig.instance.at(key, @@defaults[key.to_sym])
  end

  # self::[key] = value
  # 設定名keyに値valueを関連付ける
  def self.[]=(key, val)
    @@connect_mutex.synchronize{
      if not(@@watcher[key].empty?) then
        before_val = UserConfig.instance.at(key, @@defaults[key.to_sym])
        @@watcher[key].each{ |id|
          Thread.new(id){ |id|
            proc = nil
            @@connect_mutex.synchronize{
              if @@watcher_id.has_key?(id) then
                proc = @@watcher_id[id]
              else
                @@watcher[key].delete(id)
              end
            }
            proc.call(key, val, before_val, id) if proc
          }
        }
      end
    }
    UserConfig.instance.store(key, val)
  end

  def self.connect(key, &watcher)
    @@connect_mutex.synchronize{
      id = @@watcher_id_count
      @@watcher_id_count += 1
      @@watcher[key] << id
      @@watcher_id[id] = watcher
      id
    }
  end

  def self.disconnect(id)
    @@connect_mutex.synchronize{
      @@watcher_id.delete(id)
    }
  end

end
