# -*- coding: utf-8 -*-

require 'gtk2'

class Gtk::TimeLine < Gtk::VBox
end

miquire :mui, 'crud'
miquire :mui, 'cell_renderer_message'
miquire :mui, 'timeline_utils'
miquire :mui, 'pseudo_message_widget'
miquire :mui, 'postbox'
miquire :mui, 'inner_tl'

=begin rdoc
  タイムラインのGtkウィジェット。
=end
class Gtk::TimeLine
  include Gtk::TimeLineUtils

  attr_reader :tl

  Message::Entity.addlinkrule(:urls, URI.regexp(['http','https'])){ |segment|
    Gtk::TimeLine.openurl(segment[:url])
  }

  Message::Entity.addlinkrule(:media){ |segment|
    Gtk::TimeLine.openurl(segment[:url])
  }

  # 現在アクティブなTLで選択されているすべてのMessageオブジェクトを返す
  def self.get_active_mumbles
    if Gtk::TimeLine::InnerTL.current_tl
      InnerTL.current_tl.get_active_messages
    else
      [] end end

  def initialize
    super
    @tl = InnerTL.new
    closeup(postbox).pack_start(init_tl)
    refresh_timer
  end

  # InnerTLをすげ替える。
  def refresh
    scroll = @tl.vadjustment.value
    oldtl = @tl
    @tl = InnerTL.new
    remove(@shell)
    @shell = init_tl
    @tl.vadjustment.value = scroll
    pack_start(@shell.show_all)
    oldtl.model.each{ |model, path, iter|
      iter[InnerTL::MIRACLE_PAINTER].destroy
      _add(iter[InnerTL::MESSAGE])
    }
    @exposing_miraclepainter = []
    oldtl.destroy if not oldtl.destroyed?
  end

  # ある条件を満たしたらInnerTLを捨てて、全く同じ内容の新しいInnerTLにすげ替えるためのイベントを定義する。
  def refresh_timer
    Gtk.timeout_add(60000) {
      if(@tl.destroyed?)
        false
      else
        window_active = Plugin.filtering(:get_windows, []).first.any?(&:has_toplevel_focus?)
        @tl.hp -= 1 if not window_active
        refresh if not(InnerTL.current_tl == @tl and window_active and Plugin.filtering(:get_idle_time, nil).first < 3600) and @tl.hp <= (window_active ? -HYDE : 0)
        true end }
  end

  def init_tl
    @tl.postbox = postbox
    scrollbar = Gtk::VScrollbar.new(@tl.vadjustment)
    @tl.model.set_sort_column_id(2, order = Gtk::SORT_DESCENDING)
    @tl.model.set_sort_func(2){ |a, b|
      order = a[2] <=> b[2]
      if order == 0
        a[0] <=> b[0]
      else
        order
      end
    }
    @tl.set_size_request(100, 100)
    @tl.get_column(0).sizing = Gtk::TreeViewColumn::FIXED
    scroll_to_top_anime = false
    @tl.ssc(:scroll_event){ |this, e|
      case e.direction
      when Gdk::EventScroll::UP
        this.vadjustment.value -= this.vadjustment.step_increment
      when Gdk::EventScroll::DOWN
        this.vadjustment.value += this.vadjustment.step_increment end
      false }
    @tl.ssc(:expose_event){
      emit_expose_miraclepainter
      false }
    @tl.vadjustment.ssc(:value_changed){ |this|
        emit_expose_miraclepainter
        if(scroll_to_zero? and not(scroll_to_top_anime))
          scroll_to_top_anime = true
          scroll_speed = 4
          Gtk.timeout_add(25){
            if not(@tl.destroyed?)
              @tl.vadjustment.value -= (scroll_speed *= 2)
              scroll_to_top_anime = @tl.vadjustment.value > 0.0 end } end
      false }
    init_remover
    @shell = Gtk::HBox.new.pack_start(@tl).closeup(scrollbar) end

  # TLに含まれているMessageを順番に走査する。最新のものから順番に。
  def each(index=1)
    @tl.model.each{ |model,path,iter|
      yield(iter[index]) } end

  # TLのログを全て消去する
  def clear
    @tl.model.clear
    self end

  # 新しいものから順番にpackしていく。
  def block_add_all(messages)
    removes, appends = *messages.partition{ |m| m[:rule] == :destroy }
    remove_if_exists_all(removes)
    retweets, appends = *messages.partition{ |m| m[:retweet] }
    add_retweets(retweets)
    appends.sort_by{ |m| -(m.modified.to_i) }.each(&method(:block_add))
  end

  # リツイートを追加する。 _messages_ には Message の配列を指定し、それらはretweetでなければならない
  def add_retweets(messages)
    messages.each{ |message|
      if not include?(message.retweet_source)
        block_add(message.retweet_source)
      end
    }
  end

  # Messageオブジェクト _message_ が更新されたときに呼ばれる
  def modified(message)
    type_strict message => Message
    path = @tl.get_path_by_message(message)
    if(path)
      @tl.update!(message, 2, message.modified.to_i) end
    self end

  # _message_ が新たに _user_ のお気に入りに追加された時に呼ばれる
  def favorite(user, message)
    self
  end

  # _message_ が _user_ のお気に入りから削除された時に呼ばれる
  def unfavorite(user, message)
    self
  end

  # つぶやきが削除されたときに呼ばれる
  def remove_if_exists_all(messages)
    messages.each{ |message|
      path = @tl.get_path_by_message(message)
      @tl.model.remove(@tl.model.get_iter(path)) if path } end

  # TL上のつぶやきの数を返す
  def size
    @tl.model.to_enum(:each).inject(0){ |i, r| i + 1 } end

  # このTLが既に削除されているなら真
  def destroyed?
    @tl.destroyed? or @tl.model.destroyed? end

  def method_missing(method_name, *args, &proc)
    @tl.__send__(method_name, *args, &proc) end

  protected

  # _message_ をTLに追加する
  def block_add(message)
    type_strict message => Message
    if not @tl.destroyed?
      raise "id must than 1 but specified #{message[:id].inspect}" if message[:id] <= 0
      if(!any?{ |m| m[:id] == message[:id] })
        case
        when message[:rule] == :destroy
          remove_if_exists_all([message])
        when message.retweet?
          add_retweets([messages])
        else
          _add(message) end end end
    self end

  # Gtk::TreeIterについて繰り返す
  def each_iter
    @tl.model.each{ |model,path,iter|
      yield(iter) } end

  private

  def _add(message)
    scroll_to_zero_lator! if @tl.realized? and @tl.vadjustment.value == 0.0
    miracle_painter = @tl.cell_renderer_message.create_miracle_painter(message)
    iter = @tl.model.append
    iter[Gtk::TimeLine::InnerTL::MESSAGE_ID] = message[:id].to_s
    iter[Gtk::TimeLine::InnerTL::MESSAGE] = message
    iter[Gtk::TimeLine::InnerTL::CREATED] = message.modified.to_i
    iter[Gtk::TimeLine::InnerTL::MIRACLE_PAINTER] = miracle_painter
    # @tl.add_iter(iter)
    sid = miracle_painter.ssc(:modified, @tl, &gen_mp_modifier(message))
    @remover_queue.push(message) if @tl.realized?
    self
  end

  def gen_mp_modifier(message)
    lambda{ |mb|
      @tl.model.each{ |model, path, iter|
        if iter[0].to_i == message[:id]
          @tl.queue_draw
          break end }
      false }
  end

  # TLのMessageの数が上限を超えたときに削除するためのキューの初期化
  # オーバーしてもすぐには削除せず、1秒間更新がなければ削除するようになっている。
  def init_remover
    @timeline_max = 200
    @remover_queue = TimeLimitedQueue.new(1024, 1){ |messages|
      Delayer.new{
        if not destroyed?
          remove_count = size - timeline_max
          if remove_count > 0
            to_enum(:each_iter).to_a[-remove_count, remove_count].each{ |iter|
              @tl.hp -= 1
              @tl.model.remove(iter) } end end } } end

  # スクロールなどの理由で新しくTLに現れたMiraclePainterにシグナルを送る
  def emit_expose_miraclepainter
    @exposing_miraclepainter ||= []
    if @tl.visible_range
      current, last = @tl.visible_range.map{ |path| @tl.model.get_iter(path) }
      messages = Set.new
      while current[0].to_i >= last[0].to_i
        messages << current[1]
        break if not current.next! end
      (messages - @exposing_miraclepainter).each{ |exposed|
        @tl.cell_renderer_message.miracle_painter(exposed).signal_emit(:expose_event) }
      @exposing_miraclepainter = messages end end

  def postbox
    @postbox ||= Gtk::VBox.new end

  def scroll_to_zero_lator!
    @scroll_to_zero_lator = true end

  def scroll_to_zero?
    result = (defined?(@scroll_to_zero_lator) and @scroll_to_zero_lator)
    @scroll_to_zero_lator = false
    result end

  Delayer.new{
    plugin = Plugin::create(:core)
    plugin.add_event(:message_modified){ |message|
      ObjectSpace.each_object(Gtk::TimeLine){ |tl|
        tl.modified(message) if not(tl.destroyed?) and tl.include?(message) } }
    plugin.add_event(:destroyed){ |messages|
      ObjectSpace.each_object(Gtk::TimeLine){ |tl|
        tl.remove_if_exists_all(messages) if not(tl.destroyed?) } }
  }

  Gtk::RC.parse_string <<EOS
style "timelinestyle"
{
  GtkTreeView::vertical-separator = 0
  GtkTreeView::horizontal-separator = 0
}
widget "*.timeline" style "timelinestyle"
EOS

end
