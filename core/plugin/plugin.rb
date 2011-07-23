# -*- coding: utf-8 -*-
# Plugin
#

miquire :core, 'configloader'
miquire :core, 'environment'
miquire :core, 'delayer'

require 'monitor'
require 'set'
require 'thread'

#
#= Plugin プラグイン管理/イベント管理モジュール
#
# CHIコアにプラグインを報告します。
# Plugin.create でPluginTagのインスタンスを作り、コアにプラグインを登録します。
# イベントリスナーの登録とイベントの発行については、Plugin::PluginTagを参照してください。
#
#== プラグインの実行順序
# まず、Plugin.call()が呼ばれると、予めadd_event_filter()で登録されたフィルタ関数に
# 引数が順次通され、最終的な戻り値がadd_event()に渡される。イメージとしては、
# イベントリスナ(*フィルタ(*引数))というかんじ。
# リスナもフィルタも、実行される順序は特に規定されていない。
module Plugin

  @@eventqueue = Queue.new

  Thread.new{
    while proc = @@eventqueue.pop
      proc.call end
  }

  def self.gen_event_ring
    Hash.new{ |hash, key| hash[key] = [] }
  end
  @@event          = gen_event_ring # { event_name => [[plugintag, proc]] }
  @@add_event_hook = gen_event_ring
  @@event_filter   = gen_event_ring

  # イベントリスナーを追加する。
  def self.add_event(event_name, tag, &callback)
    @@event[event_name.to_sym] << [tag, callback]
    call_add_event_hook(event_name, callback)
    callback end

  # イベントフィルタを追加する。
  # フィルタは、イベントリスナーと同じ引数で呼ばれるし、引数の数と同じ数の値を
  # 返さなければいけない。
  def self.add_event_filter(event_name, tag, &callback)
    @@event_filter[event_name.to_sym] << [tag, callback]
    callback end

  def self.fetch_event(event_name, tag, &callback)
    call_add_event_hook(event_name, callback)
    callback end

  def self.add_event_hook(event_name, tag, &callback)
    @@add_event_hook[event_name.to_sym] << [tag, callback]
    callback end

  def self.detach(event_name, event)
    deleter = lambda{|events| events[event_name.to_sym].reject!{ |e| e[1] == event } }
    deleter.call(@@event) or deleter.call(@@event_filter) or deleter.call(@@add_event_hook) end

  # フィルタ関数を用いて引数をフィルタリングする
  def self.filtering(event_name, *args)
    length = args.size
    catch(:filter_exit){
      @@event_filter[event_name.to_sym].inject(args){ |store, plugin|
        result = store
        plugintag, proc = *plugin
        boot_plugin(plugintag, event_name, :filter, false){
          result = proc.call(*store){ |result| throw(:filter_exit, result) }
          if length != result.size
            raise "filter changes arguments length (#{length} to #{result.size})" end
          result } } } end

  # イベント _event_name_ を呼ぶ予約をする。第二引数以降がイベントの引数として渡される。
  # 実際には、これが呼ばれたあと、することがなくなってから呼ばれるので注意。
  def self.call(event_name, *args)
    SerialThread.new{
      plugin_callback_loop(@@event, event_name, :proc, *filtering(event_name, *args)) } end

  # イベントが追加されたときに呼ばれるフックを呼ぶ。
  # _callback_ には、登録されたイベントのProcオブジェクトを渡す
  def self.call_add_event_hook(event_name, callback)
    plugin_callback_loop(@@add_event_hook, event_name, :hook, callback) end

  # plugin_loopの簡略化版。プラグインに引数 _args_ をそのまま渡して呼び出す
  def self.plugin_callback_loop(ary, event_name, kind, *args)
    plugin_loop(ary, event_name, kind){ |tag, proc|
      proc.call(*args){ throw(:plugin_exit) } } end

  # _ary_ [ _event\_name_ ] に登録されているプラグイン一つひとつを引数に _proc_ を繰り返し呼ぶ。
  # _proc_ のシグニチャは以下の通り。
  #   _proc_ ( プラグイン名, コールバック )
  def self.plugin_loop(ary, event_name, kind, &proc)
    ary[event_name.to_sym].each{ |plugin|
      boot_plugin(plugin.first, event_name, kind){
         proc.call(*plugin) } } end

  # プラグインを起動できるならyieldする。コールバックに引数は渡されない。
  def self.boot_plugin(plugintag, event_name, kind, delay = true, &routine)
    if(plugintag.active?)
      if(delay)
        Delayer.new{ call_routine(plugintag, event_name, kind, &routine) }
      else
        call_routine(plugintag, event_name, kind, &routine) end end end

  # プラグインタグをなければ作成して返す。
  def self.create(name)
    PluginTag.create(name) end

  # ブロックの実行時間を記録しながら実行
  def self.call_routine(plugintag, event_name, kind)
    catch(:plugin_exit){ yield } end
    # begin
    #   yield
    # rescue Exception => e
    #   plugin_fault(plugintag, event_name, kind, e) end

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
      result[pair[0]][event] << proc }
    result
  end

  # 登録済みプラグイン名を一次元配列で返す
  def self.plugin_list
    Plugin::PluginTag.plugins end

  # プラグイン処理中に例外が発生した場合、アプリケーションごと落とすかどうかを返す。
  # trueならば、その場でバックトレースを吐いて落ちる、falseならエラーを表示してプラグインをstopする
  def self.abort_on_exception?
    true end

  def self.plugin_fault(plugintag, event_name, event_kind, e)
    error e
    if abort_on_exception?
      abort
    else
      Plugin.call(:update, nil, [Message.new(:message => "プラグイン #{plugintag} が#{event_kind} #{event_name} 処理中にクラッシュしました。プラグインの動作を停止します。\n#{e.to_s}",
                                             :system => true)])
      plugintag.stop! end end
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

=== message_modified(Message message)
messageの内容が変わったときに呼ばれる。
おもに、ふぁぼられ数やRT数が変わったときに呼ばれる。

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

=== retweet(Array messages)
リツイートを受信したときに呼ばれる

=== favorite(Post service, User user, Message message)
_user_ が _message_ をお気に入りに追加した時に呼ばれる。

=== unfavorite(Post service, User user, Message message)
_user_ が _message_ をお気に入りから外した時に呼ばれる。

=== after_event(Post service)
periodなど、毎分実行されるイベントのクロールが終わった後に呼び出される。

=== play_sound(String filename)
ファイル名 _filename_ の音楽ファイルを鳴らす。

=== popup_notify(User user, String text)
通知を表示する。雰囲気としては、
- Windows : バルーン
- Linux : libnotify
- Mac : Growl
みたいなイメージの通知。 _user_ のアイコンが使われ、名前がタイトルになり、本文は _text_ が使われる。

=== query_start(:serial => Integer, :method => Symbol|String, :path => String, :options => Hash, :start_time => Time)
HTTP問い合わせが始まった時に呼ばれる。
serial::
  コネクションのID
method::
  HTTPメソッド名。GETやPOSTなど
path::
  サーバ上のパス。/statuses/show.json など
options::
  雑多な呼び出しオプション。
start_time::
  クエリの開始時間

=== query_end(:serial => Integer, :method => Symbol|String, :path => String, :options => Hash, :start_time => Time, :end_time => Time, :res => Net::HTTPResponse|Exception)
HTTP問い合わせが終わった時に呼ばれる。
serial::
  コネクションのID
method::
  HTTPメソッド名。GETやPOSTなど
path::
  サーバ上のパス。/statuses/show.json など
options::
  雑多な呼び出しオプション。
start_time::
  クエリの開始時間
end_time::
  クエリのレスポンスを受け取った時間。
res::
  受け取ったレスポンス。通常はNet::HTTPResponseを渡す。捕捉できない例外が発生した場合はここにその例外を渡す。

== フィルタ

以下に、フックできる主なフィルタを示す。

=== favorited_by(Message message, Set users)
_message_ をお気に入りに入れているユーザを取得するためのフック。
_users_ は、お気に入りに入れているユーザの集合。

=== show_filter(Enumerable messages)
_messages_ から、表示してはいけないものを取り除く

=end
class Plugin::PluginTag

  include ConfigLoader

  @@plugins = [] # plugin

  attr_reader :name
  alias to_s name

  def initialize(name = :anonymous)
    @name = name
    active!
    regist end

  # 新しくプラグインを作成する。もしすでに同じ名前で作成されていれば、新しく作成せずにそれを返す。
  def self.create(name)
    plugin = @@plugins.find{ |p| p.name == name }
    if plugin
      plugin
    else
      Plugin::PluginTag.new(name) end end

  def self.plugins
    @@plugins
  end

  # イベント _event_name_ を監視するイベントリスナーを追加する。
  def add_event(event_name, &callback)
    Plugin.add_event(event_name, self, &callback)
  end

  # イベントフィルタを設定する。
  # フィルタが存在した場合、イベントが呼ばれる前にイベントフィルタに引数が渡され、戻り値の
  # 配列がそのまま引数としてイベントに渡される。
  # フィルタは渡された引数と同じ長さの配列を返さなければいけない。
  def add_event_filter(event_name, &callback)
    Plugin.add_event_filter(event_name, self, &callback)
  end

  def fetch_event(event_name, &callback)
    Plugin.fetch_event(event_name, self, &callback)
  end

  # イベント _event_name_ にイベントが追加されたときに呼ばれる関数を登録する。
  def add_event_hook(event_name, &callback)
    Plugin.add_event_hook(event_name, self, &callback)
  end

  # イベントの監視をやめる。引数 _event_ には、add_event, add_event_filter, add_event_hook の
  # いずれかの戻り値を与える。
  def detach(event_name, event)
    Plugin.detach(event_name, event)
  end

  def at(key, ifnone=nil)
    super("#{@name}_#{key}".to_sym, ifnone) end

  def store(key, val)
    super("#{@name}_#{key}".to_sym, val) end

  def stop!
    @status = :stop end

  def stop?
    @status == :stop end

  def active!
    @status = :active end

  def active?
    @status == :active end

  private

  def regist
    @@plugins.push(self) end
end

Module.new do
  def self.gen_never_message_filter
    appeared = Set.new
    lambda{ |service, messages|
      [service,
       messages.select{ |m|
         appeared.add(m[:id].to_i) if m and not(appeared.include?(m[:id].to_i)) }] } end

  def self.never_message_filter(event_name, *other)
    Plugin.create(:core).add_event_filter(event_name, &gen_never_message_filter)
    never_message_filter(*other) unless other.empty?
  end

  never_message_filter(:update, :mention)

  Plugin.create(:core).add_event(:appear){ |messages|
    retweets = messages.select(&:retweet?)
    if not(retweets.empty?)
      Plugin.call(:retweet, retweets) end }
end

miquire :plugin # if defined? Test::Unit
