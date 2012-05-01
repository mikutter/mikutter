# -*- coding: utf-8 -*-
# Plugin
#

miquire :core, 'configloader', 'environment', 'delayer'
require 'monitor'
require 'set'
require 'thread'

=begin rdoc

= Plugin プラグイン管理/イベント管理クラス

Plugin.create で、コアにプラグインを登録します。

== プラグインの実行順序

まず、Plugin.call()が呼ばれると、予めadd_event_filter()で登録されたフィルタ関数に
引数が順次通され、最終的な戻り値がadd_event()に渡される。イメージとしては、
イベントリスナ(*フィルタ(*引数))というかんじ。
リスナもフィルタも、実行される順序は特に規定されていない。

== イベントの種類

 以下に、監視できる主なイベントを示す。

=== boot(Service service)
起動時に、どのイベントよりも先に一度だけ呼ばれる。

=== period(Service service)
毎分呼ばれる。必ず60秒ごとになる保証はない。

=== update(Service service, Array messages)
フレンドタイムラインが更新されたら呼ばれる。ひとつのつぶやきはかならず１度しか引数に取られず、
_messages_ には同時に複数の Message のインスタンスが渡される(ただし、削除された場合は削除フラグを
立てて同じつぶやきが流れる)。

=== mention(Service service, Array messages)
updateと同じ。ただし、自分宛のリプライが来たときに呼ばれる点が異なる。

=== posted(Service service, Array messages)
自分が投稿したメッセージ。

=== appear(Array messages)
updateと同じ。ただし、タイムライン、検索結果、リスト等、受信したすべてのつぶやきを対象にしている。

=== message_modified(Message message)
messageの内容が変わったときに呼ばれる。
おもに、ふぁぼられ数やRT数が変わったときに呼ばれる。

=== followings_created(Service service, Array users)
_service_ フォロイーが増えた時に呼ばれる。_users_ は増えたフォロイー(User)の配列

=== followers_created(Service service, Array users)
_service_ のフォロワーが増えた時に呼ばれる。_users_ は増えたフォロワー(User)の配列

=== follow(User by, User to)
ユーザ _by_ がユーザ _to_ をフォローした時に呼ばれる

=== list_data(Service service, Array ulist)
フォローしているリスト一覧に変更があれば呼ばれる。なお、このイベントにリスナーを登録すると、すぐに
現在フォローしているリスト一覧を引数にコールバックが呼ばれる。

=== list_created(Service service, Array ulist)
新しくリストが作成されると、それを引数に呼ばれる。

=== list_destroy(Service service, Array ulist)
リストが削除されると、それを引数に呼ばれる。

=== list_member_changed(UserList list)
リストにメンバーの追加・削除があれば呼び出される。
ただし、実際に追加・削除がされたのではなく、mikutterが初めて掌握しただけでもこれが呼び出される。

=== list_member_added(User target_user, UserList list, User source_user)
_source_user_ が、 _target_user_ をリスト _list_ に追加した時に呼ばれる。
自分がリストにユーザを追加した時や、人のリストに自分が追加されたときにも呼ばれる可能性がある。

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

=== favorite(Service service, User user, Message message)
_user_ が _message_ をお気に入りに追加した時に呼ばれる。

=== unfavorite(Service service, User user, Message message)
_user_ が _message_ をお気に入りから外した時に呼ばれる。

=== before_favorite(Service service, User user, Message message)
mikutterを操作してお気に入りに追加する操作をした時に、APIを叩く前に呼ばれる。

=== fail_favorite(Service service, User user, Message message)
before_favoriteイベントを発生させてからAPIを叩いて、リクエストが失敗した時に呼ばれる。

=== after_event(Service service)
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

=== message_background_color(Gdk::MiraclePainter miracle_painter, Array color)
_miracle_painter_ のツイートの背景色を変更する。 _color_ は現在の色又はnil。
_color_ は、0-65535までのRGB値でを含む三要素の配列([65535, 65535, 65535] 等)。

=== message_font_color(Gdk::MiraclePainter miracle_painter, Array color)
_miracle_painter_ のツイート本文の文字色を変更する。 _color_ は現在の色又はnil。
_color_ は、0-65535までのRGB値でを含む三要素の配列([65535, 65535, 65535] 等)。

=== message_header_left_font_color(Gdk::MiraclePainter miracle_painter, Array color)
_miracle_painter_ のツイート本文の文字色を変更する。 _color_ は現在の色又はnil。
_color_ は、0-65535までのRGB値でを含む三要素の配列([65535, 65535, 65535] 等)。

=== message_header_right_font_color(Gdk::MiraclePainter miracle_painter, Array color)
_miracle_painter_ のツイート本文の文字色を変更する。 _color_ は現在の色又はnil。
_color_ は、0-65535までのRGB値でを含む三要素の配列([65535, 65535, 65535] 等)。

=== message_font(Gdk::MiraclePainter miracle_painter, String font)
_miracle_painter_ のツイート本文のフォントを変更する。 _font_ は現在のフォント又はnil。

=== message_header_left_font(Gdk::MiraclePainter miracle_painter, String font)
_miracle_painter_ のツイート本文のフォントを変更する。 _font_ は現在のフォント又はnil。

=== message_header_right_font(Gdk::MiraclePainter miracle_painter, String font)
_miracle_painter_ のツイート本文のフォントを変更する。 _font_ は現在のフォント又はnil。

=end

class Plugin

  class << self
    @@eventqueue = Queue.new
    EventFilterThread = SerialThreadGroup.new

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
    def add_event(event_name, tag, &callback)
      @@event[event_name.to_sym] << [tag, callback]
      call_add_event_hook(event_name, callback)
      callback end

    # イベントフィルタを追加する。
    # フィルタは、イベントリスナーと同じ引数で呼ばれるし、引数の数と同じ数の値を
    # 返さなければいけない。
    def add_event_filter(event_name, tag, &callback)
      @@event_filter[event_name.to_sym] << [tag, callback]
      callback end

    def fetch_event(event_name, tag, &callback)
      call_add_event_hook(event_name, callback)
      callback end

    def add_event_hook(event_name, tag, &callback)
      @@add_event_hook[event_name.to_sym] << [tag, callback]
      callback end

    def detach(event_name, event)
      deleter = lambda{ |events|
        events[event_name.to_sym].reject!{ |e| e[1] == event } }
      deleter.call(@@event) or deleter.call(@@event_filter) or deleter.call(@@add_event_hook) end

    # プラグインをアンインストールする
    # ==== Args
    # [name] プラグイン名(Symbol)
    def uninstall(name)
      name = name.to_sym
      plugin = Plugin.create(name)
      [@@event, @@event_filter, @@add_event_hook].each{ |event_ring|
        event_ring.dup.each{ |event_name, events|
          event_ring[event_name] = events.reject{ |e|
            e[0].to_sym == name } } }
      plugin.execute_unload_hook
      @@plugins.delete(plugin)
    end

    # フィルタ内部で使う。フィルタの実行をキャンセルする。Plugin#filtering はfalseを返し、
    # イベントのフィルタの場合は、そのイベントの実行自体をキャンセルする
    def filter_cancel!
      throw :filter_exit, false end

    # フィルタ関数を用いて引数をフィルタリングする
    def filtering(event_name, *args)
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
    def call(event_name, *args)
      Delayer.new{
        filtered = filtering(event_name, *args)
        plugin_callback_loop(@@event, event_name, :proc, *filtered) if filtered } end

    # イベントが追加されたときに呼ばれるフックを呼ぶ。
    # _callback_ には、登録されたイベントのProcオブジェクトを渡す
    def call_add_event_hook(event_name, callback)
      plugin_callback_loop(@@add_event_hook, event_name, :hook, callback) end

    # plugin_loopの簡略化版。プラグインに引数 _args_ をそのまま渡して呼び出す
    def plugin_callback_loop(ary, event_name, kind, *args)
      plugin_loop(ary, event_name, kind){ |tag, proc|
        if Mopt.debug
          r_start = Process.times.utime
          result = proc.call(*args){ throw(:plugin_exit) }
          if (r_end = Process.times.utime - r_start) > 0.1
            Plugin.call(:processtime, :plugin, "#{"%.2f" % r_end},#{tag.name},#{event_name},#{kind}") end
          result
        else
          proc.call(*args){ throw(:plugin_exit) } end } end

    # _ary_ [ _event\_name_ ] に登録されているプラグイン一つひとつを引数に _proc_ を繰り返し呼ぶ。
    # _proc_ のシグニチャは以下の通り。
    #   _proc_ ( プラグイン名, コールバック )
    def plugin_loop(ary, event_name, kind, &proc)
      ary[event_name.to_sym].each{ |plugin|
        boot_plugin(plugin.first, event_name, kind){
          proc.call(*plugin) } } end

    # プラグインを起動できるならyieldする。コールバックに引数は渡されない。
    def boot_plugin(plugintag, event_name, kind, delay = true, &routine)
      if(plugintag.active?)
        if(delay)
          Delayer.new{ call_routine(plugintag, event_name, kind, &routine) }
        else
          call_routine(plugintag, event_name, kind, &routine) end end end

    # プラグインタグをなければ作成して返す。
    # ブロックを渡した場合、返されるPluginTagのコンテキストでブロックが実行される。

    def plugins
      @@plugins
    end

    # ブロックの実行時間を記録しながら実行
    def call_routine(plugintag, event_name, kind)
      catch(:plugin_exit){ yield }
    end

    # 登録済みプラグインの一覧を返す。
    # 返すHashは以下のような構造。
    #  { plugin tag =>{
    #      event name => [proc]
    #    }
    #  }
    # plugin tag:: Plugin::PluginTag のインスタンス
    # event name:: イベント名。Symbol
    # proc:: イベント発生時にコールバックされる Proc オブジェクト。
    def plugins
      result = Hash.new{ |hash, key|
        hash[key] = Hash.new{ |hash, key|
          hash[key] = [] } }
      @@event.each_pair{ |event, pair|
        result[pair[0]][event] << proc }
      result
    end

    # 登録済みプラグイン名を一次元配列で返す
    def plugin_list
      Plugin.plugins end

    # プラグイン処理中に例外が発生した場合、アプリケーションごと落とすかどうかを返す。
    # trueならば、その場でバックトレースを吐いて落ちる、falseならエラーを表示してプラグインをstopする
    def abort_on_exception?
      true end

    def plugin_fault(plugintag, event_name, event_kind, e)
      error e
      if abort_on_exception?
        abort
      else
        Plugin.activity :system, "プラグイン #{plugintag} が#{event_kind} #{event_name} 処理中にクラッシュしました。プラグインの動作を停止します。\n#{e.to_s}"
        plugintag.stop! end end

    alias :newSAyTof :new
    def new(name)
      plugin = @@plugins.find{ |p| p.name == name }
      if plugin
        plugin
      else
        plugin = newSAyTof(name) end
      if block_given?
        catch(:plugin_define_exit) {
          plugin.instance_eval(&Proc.new) } end
      plugin end
    alias :create :new
  end

  include ConfigLoader

  @@plugins = [] # plugin

  attr_reader :name

  def initialize(name = :anonymous)
    @name = name
    active!
    regist end

  def create(name)
    new(name) end

  def to_s
    @name.to_s end

  def to_sym
    @name.to_sym end

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

  # プラグインが Plugin.uninstall される時に呼ばれるブロックを登録する。
  def onunload
    @unload_hook ||= []
    @unload_hook.push(Proc.new) end

  def execute_unload_hook
    @unload_hook.each{ |unload| unload.call } if(defined?(@unload_hook)) end

  def method_missing(method, *args, &proc)
    case method.to_s
    when /^on_?(.+)$/
       add_event($1, &proc)
    when /^filter_?(.+)$/
       add_event_filter($1, &proc)
    when /^hook_?(.+)$/
      add_event_hook($1, &proc)
    else
      super end end

  # 設定画面を作る
  # ==== Args
  # - String name タイトル
  # - Proc &place 設定画面を作る無名関数
  def settings(name, &place)
    Plugin.call(:settings, name, place)
    filter_defined_settings do |tabs|
      [tabs.melt << [name, place]] end end

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

  def self.never_message_filter(event_name, &filter_func)
    Plugin.create(:core).add_event_filter(event_name, &(filter_func || gen_never_message_filter))
  end

  never_message_filter :update
  never_message_filter :mention
  appeared = Set.new
  never_message_filter(:appear){ |messages|
    [messages.select{ |m|
       appeared.add(m[:id].to_i) if m and not(appeared.include?(m[:id].to_i)) }] }

  Plugin.create(:core) do
    favorites = Hash.new{ |h, k| h[k] = Set.new } # {user_id: set(message_id)}
    unfavorites = Hash.new{ |h, k| h[k] = Set.new } # {user_id: set(message_id)}

    onappear do |messages|
      retweets = messages.select(&:retweet?)
      if not(retweets.empty?)
        Plugin.call(:retweet, retweets) end end

    # 同じツイートに対するfavoriteイベントは一度しか発生させない
    filter_favorite do |service, user, message|
      Plugin.filter_cancel! if favorites[user[:id]].include? message[:id]
      favorites[user[:id]] << message[:id]
      [service, user, message]
    end

    # 同じツイートに対するunfavoriteイベントは一度しか発生させない
    filter_unfavorite do |service, user, message|
      Plugin.filter_cancel! if unfavorites[user[:id]].include? message[:id]
      unfavorites[user[:id]] << message[:id]
      [service, user, message]
    end

    # followers_createdイベントが発生したら、followイベントも発生させる
    on_followers_created do |service, users|
      users.each{ |user|
        Plugin.call(:follow, user, service.user_obj) } end

    # followings_createdイベントが発生したら、followイベントも発生させる
    on_followings_created do |service, users|
      users.each{ |user|
        Plugin.call(:follow, service.user_obj, user) } end

  end

end

miquire :mui,
'cell_renderer_message', 'coordinate_module', 'icon_over_button', 'inner_tl', 'markup_generator',
'miracle_painter', 'pseudo_message_widget', 'replyviewer', 'sub_parts_favorite', 'sub_parts_helper',
'sub_parts_retweet', 'sub_parts_voter', 'textselector', 'timeline', 'contextmenu', 'crud',
'extension', 'intelligent_textview', 'keyconfig', 'listlist', 'message_picker', 'mtk', 'postbox',
'pseudo_signal_handler', 'selectbox', 'skin', 'timeline_utils', 'userlist', 'webicon'
