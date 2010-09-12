#
# Plugin
#

miquire :core, 'configloader'
miquire :core, 'environment'
miquire :core, 'delayer'

require 'monitor'

#
#= Plugin プラグイン管理/イベント管理モジュール
#
# CHIコアにプラグインを報告します。
# Plugin.create でPluginTagのインスタンスを作り、コアにプラグインを登録します。
# イベントリスナーの登録とイベントの発行については、Plugin::PluginTagを参照してください。
#
module Plugin
  @@event          = Hash.new{ |hash, key| hash[key] = [] } # { event_name => [[plugintag, proc]] }
  @@add_event_hook = Hash.new{ |hash, key| hash[key] = [] }

  # イベントリスナーを追加する。
  def self.add_event(event_name, tag, &callback)
    @@event[event_name.to_sym] << [tag, callback]
    call_add_event_hook(callback, event_name)
    callback end

  def self.fetch_event(event_name, tag, &callback)
    call_add_event_hook(callback, event_name)
    callback end

  def self.add_event_hook(event_name, tag, &callback)
    @@add_event_hook[event_name.to_sym] << [tag, callback]
    callback end

  def self.detach(event_name, event)
    @@event[event_name.to_sym].delete_if{ |e| e[1] == event } end

  # イベント _event_name_ を呼ぶ予約をする。第二引数以降がイベントの引数として渡される。
  # 実際には、これが呼ばれたあと、することがなくなってから呼ばれるので注意。
  def self.call(event_name, *args)
    @@event[event_name.to_sym].each{ |plugin|
      Delayer.new{
        plugin[1].call(*args) } } end

  def self.call_add_event_hook(event, event_name)
    @@add_event_hook[event_name.to_sym].each{ |plugin|
      Delayer.new{
        plugin[1].call(event) } } end

  # プラグインタグをなければ作成して返す。
  def self.create(name)
    PluginTag.create(name) end

  # 登録済みプラグインの一覧を返す。
  # 返すHashは以下のような構造。
  #  { plugin tag =>{
  #      event name => [proc]
  #    }
  #  }
  # plugin tag:: Plugin::PluginTag のインスタンス
  # event name:: イベント名。Symbol
  # proc:: イベント発生時にコールバックされる Proc オブジェクト。
  def self.plugins
    result = Hash.new{ |hash, key|
      hash[key] = Hash.new{ |hash, key|
        hash[key] = [] } }
    @@event.each_pair{ |event, pair|
      result[pair[0]][event] << proc
    }
    result
  end

end

=begin rdoc

= Plugin プラグインタグクラス

 プラグインを一意に識別するためのタグ。
 newは使わずに、 Plugin.create でインスタンスを作ること。

== イベントの種類

 以下に、監視できる主なイベントを示す。

=== boot(Post service)
起動時に、どのイベントよりも先に一度だけ呼ばれる。
=== period(Post service)
毎分呼ばれる。必ず60秒ごとになる保証はない。
=== update(Post service, Array messages)
フレンドタイムラインが更新されたら呼ばれる。ひとつのつぶやきはかならず１度しか引数に取られず、
_messages_ には同時に複数の Message のインスタンスが渡される(ただし、削除された場合は削除フラグを
立てて同じつぶやきが流れる)。
=== mention(Post service, Array messages)
updateと同じ。ただし、自分宛のリプライが来たときに呼ばれる点が異なる。
=== posted(Post service, Array messages)
自分が投稿したメッセージ。
=== appear(Array messages)
updateと同じ。ただし、タイムライン、検索結果、リスト等、受信したすべてのつぶやきを対象にしている。
=== list_data(Post service, Array ulist)
フォローしているリスト一覧に変更があれば呼ばれる。なお、このイベントにリスナーを登録すると、すぐに
現在フォローしているリスト一覧を引数にコールバックが呼ばれる。
=== list_created(Post service, Array ulist)
新しくリストが作成されると、それを引数に呼ばれる。
=== list_destroy(Post service, Array ulist)
リストが削除されると、それを引数に呼ばれる。
=== mui_tab_regist(Gtk::Widget container, String label, String image=nil)
ウィンドウにタブを追加する。 _label_ はウィンドウ内での識別名にも使われるので一意であること。
_image_ は画像への相対パスかURLで、通常は #MUI::Skin.get の戻り値を使う。
_image_ が省略された場合は、 _label_ が使われる。
=== mui_tab_remove(String label)
ラベル _label_ をもつタブを削除する。
=== mui_tab_active(String label)
ラベル _label_ のついたタブをアクティブにする。
=== apilimit(Time time)
サーバによって、時間 _time_ までクエリの実行を停止された時に呼ばれる。
=== apifail(String text)
何らかのクエリが実行に失敗した場合に呼ばれる。サーバからエラーメッセージが帰ってきた場合は
_text_ に渡される。エラーメッセージが得られなかった場合はnilが渡される。
=== apiremain(Integer remain, Time expire, String transaction)
サーバへのクリエ発行が時間 _expire_ までに _remain_ 回実行できることを通知するために呼ばれる。
現在のTwitterの仕様では、クエリを発行するたびにこれが呼ばれる。
=== ipapiremain(Integer remain, Time expire, String transaction)
基本的にはapiremainと同じだが、IPアドレス規制について動くことが違う。
=== rewindstatus(String mes)
ユーザに情報 _mes_ を「さりげなく」提示する。 GUI プラグインがハンドルしていて、ステータスバーを
更新する。

=end
class Plugin::PluginTag

  include ConfigLoader

  @@plugins = [] # plugin

  attr_reader :name

  def initialize(name = :anonymous)
    @name = name
    regist end

  # 新しくプラグインを作成する。もしすでに同じ名前で作成されていれば、新しく作成せずにそれを返す。
  def self.create(name)
    plugin = @@plugins.find{ |p| p.name == name }
    if plugin
      plugin
    else
      Plugin::PluginTag.new(name) end end

  # イベント _event_name_ を監視するイベントリスナーを追加する。
  def add_event(event_name, &callback)
    Plugin.add_event(event_name, self, &callback)
  end

  def fetch_event(event_name, &callback)
    Plugin.fetch_event(event_name, self, &callback)
  end

  # イベント _event_name_ にイベントが追加されたときに呼ばれる関数を登録する。
  def add_event_hook(event_name, &callback)
    Plugin.add_event_hook(event_name, self, &callback)
  end

  # イベントの監視をやめる。引数 _event_ には、add_event の戻り値を与える。
  def detach(event_name, event)
    Plugin.detach(event_name, event)
  end

  def at(key, ifnone=nil)
    super("#{@name}_#{key}".to_sym, ifnone) end

  def store(key, val)
    super("#{@name}_#{key}".to_sym, val) end

  private

  def regist
    atomic{
      @@plugins.push(self) } end
end

miquire :plugin
