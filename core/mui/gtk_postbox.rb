# -*- coding:utf-8 -*-
=begin
= Gtk::PostBox
つぶやき入力ボックス。
=end

require 'gtk2'
require 'thread'
miquire :mui, 'miracle_painter'
miquire :mui, 'intelligent_textview'

module Gtk
  class PostBox < Gtk::EventBox
    attr_accessor :return_to_top

    @@ringlock = Mutex.new
    @@postboxes = []

    # 既存のGtk::PostBoxのインスタンスを返す
    def self.list
      return @@postboxes
    end

    # ==== Args
    # [postable] Service|Message リプライ先か、投稿するアカウント(3.3 obsolete)
    # [to] Enumerable 返信するMessage
    # [from] Diva::Model|nil 送信者。nilを指定すると、その時のカレントワールドになる
    # [header] String テキストフィールドのカーソルの前に最初から入力されている文字列
    # [footer] String テキストフィールドのカーソルの後ろに最初から入力されている文字列
    # [to_display_only] true|false toに宛てたリプライを送るなら偽。真ならUI上にtoが表示されるだけ
    # [use_blind_footer] true|false blind footerを追加するか否か
    # [visibility] Symbol|nil compose Spellに渡すvisibilityオプションの値
    # [target_world] Diva::Model|nil 対象とするWorld。nilを指定するとその時々の :world_current フィルタの値を使う
    # [kwrest] Hash 以下の値から成る連想配列
    #   - delegated_by :: Gtk::PostBox 投稿処理をこのPostBoxに移譲したPostBox
    #   - postboxstorage :: Gtk::Container PostBoxの親で、複数のPostBoxを持つことができるコンテナ
    #   - delegate_other :: true|false|Proc 投稿時、このPostBoxを使わないで、新しいPostBoxで投稿する。そのPostBoxにはdelegated_byに _self_ が設定される。Procを指定した場合、新しいPostBoxを作る処理として、その無名関数を使う
    #   - before_post_hook :: Proc 投稿前に、 _self_ を引数に呼び出される
    def initialize(postable = nil,
                   to: [],
                   from: nil,
                   header: ''.freeze,
                   footer: ''.freeze,
                   to_display_only: false,
                   use_blind_footer: true,
                   visibility: nil,
                   target_world: nil,
                   **kwrest)
      mainthread_only
      @posting = nil
      @return_to_top = nil
      @options = kwrest

      @from = from
      @to = (Array(to) + Array(@options[:subreplies])).uniq.freeze
      if postable
        warn "Gtk::Postbox.new(postable) is deprecated. see https://mikutter.hachune.net/rdoc/Gtk/PostBox.html"
        case postable
        when Message
          @to = [postable, *@to].freeze unless @to.include? postable
        when Diva::Model
          @from = postable
        end
      end
      @header = (header || '').freeze
      @footer = (footer || '').freeze
      @to_display_only = !!to_display_only
      @use_blind_footer = !!use_blind_footer
      @visibility = visibility
      @target_world = target_world
      super()
      ssc(:parent_set) do
        if parent
          sw = get_ancestor(Gtk::ScrolledWindow)
          if sw
            @return_to_top = sw.vadjustment.value == 0
          else
            @return_to_top = false
          end
          post_it if @options[:delegated_by]
        end
      end
      add(generate_box)
      set_border_width(2)
      register end

    def widget_post
      return @post if defined?(@post)
      @post = gen_widget_post
      post_set_default_text(@post)
      @post.wrap_mode = Gtk::TextTag::WRAP_CHAR
      @post.border_width = 2
      @post.buffer.ssc('changed') { |textview|
        refresh_buttons(false)
        false }
      @post.signal_connect_after('focus_out_event', &method(:focus_out_event))
      @post end
    alias post widget_post

    def widget_remain
      return @remain if defined?(@remain)
      @remain = Gtk::Label.new('---')
      tag = Plugin[:gtk].handler_tag
      @remain.ssc_atonce(:expose_event) {
        Plugin[:gtk].on_world_change_current(tags: tag) { |world|
          update_remain_charcount
        }
        false
      }
      @remain.ssc(:destroy) {
        Plugin[:gtk].detach(tag)
      }
      Delayer.new{
        update_remain_charcount
      }
      widget_post.buffer.ssc(:changed){ |textview, event|
        update_remain_charcount
      }
      @remain end

    def widget_send
      return @send if defined?(@send)
      @send = Gtk::Button.new.add(Gtk::WebIcon.new(Skin.get_path('post.png'), 16, 16))
      @send.sensitive = postable?
      @send.ssc(:clicked) do |button|
        post_it
        false
      end
      @send
    end

    def widget_tool
      return @tool if defined?(@tool)
      @tool = Gtk::Button.new.add(Gtk::WebIcon.new(Skin.get_path('close.png'), 16, 16))
      @tool.signal_connect_after('focus_out_event', &method(:focus_out_event))
      @tool.ssc(:event) do
        @tool.sensitive = destructible? || posting?
        false
      end
      @tool.ssc(:clicked) do
        if posting?
          @posting.cancel
          @tool.sensitive = destructible? || posting?
          cancel_post
        else
          destroy if destructible?
        end
        false
      end
      @tool
    end

    # 各ボタンのクリック可否状態を更新する
    def refresh_buttons(refresh_brothers = true)
      if refresh_brothers and @options.has_key?(:postboxstorage)
        @options[:postboxstorage].children.each{ |brother|
          brother.refresh_buttons(false) }
      else
        widget_send.sensitive = postable?
        widget_tool.sensitive = destructible? || posting? end end

    # 現在メッセージの投稿中なら真を返す
    def posting?
      !!@posting end

    # このPostBoxを使って投稿したとき、delegateを作成するように設定されていれば真を返す
    def delegatable?
      @options[:delegate_other] end

    # このPostBoxにフォーカスを合わせる
    def active
      get_ancestor(Gtk::Window).set_focus(widget_post) if(get_ancestor(Gtk::Window)) end

    # 入力されている投稿する。投稿に成功したら、self.destroyを呼んで自分自身を削除する
    # ==== Args
    # [world:] 投稿先のWorld。省略するかnilを渡すと :world_current フィルタの結果が使われる
    def post_it(world: target_world)
      if postable?
        return unless before_post(world: world || target_world)
        @posting = Plugin[:gtk].compose(
          world || target_world,
          to_display_only? ? nil : @to.first,
          **compose_options
        ).next{
          destroy
        }.trap{ |err|
          warn err
          end_post
        }
        start_post
      end
    end

    def destroy
      @@ringlock.synchronize{
        if not(destroyed?) and not(frozen?) and parent
          parent.remove(self)
          @@postboxes.delete(self)
          super
          on_delete
          self.freeze end } end

    private

    def generate_box
      @reply_widgets = []
      result = Gtk::HBox.new(false, 0).closeup(widget_tool).pack_start(widget_post).closeup(widget_remain).closeup(widget_send)
      w_replies = Gtk::VBox.new.add(result)
      @to.select{|m|m.respond_to?(:description)}.each{ |message|
        w_reply = Gtk::HBox.new
        itv = Gtk::IntelligentTextview.new(message.description, 'font' => :mumble_basic_font)
        itv.style_generator = lambda{ get_backgroundstyle(message) }
        itv.bg_modifier
        ev = Gtk::EventBox.new
        ev.style = get_backgroundstyle(message)
        w_reply.closeup(Gtk::WebIcon.new(message.icon, 32, 32).top) if message.respond_to?(:icon)
        w_replies.closeup(ev.add(w_reply.add(itv)))
        @reply_widgets << itv }
      w_replies end

    def gen_widget_post
      Gtk::TextView.new end

    def postable?
      not(widget_post.buffer.text.empty?) and (/[^\p{blank}]/ === widget_post.buffer.text) and Plugin[:gtk].compose?(target_world, to_display_only? ? nil : @to.first, visibility: @visibility)
    end

    # 新しいPostBoxを作り、そちらにフォーカスを回す
    # ==== Args
    # [world:] 投稿先のWorld。省略すると :world_current フィルタの結果が使われる
    # ==== Return
    # true :: 投稿を続ける
    # false :: 別の Gtk::Postbox で投稿を開始した
    def before_post(world: nil)
      return false if delegate(world: world)
      @options[:before_post_hook]&.call(self)
      Plugin.call(:before_postbox_post, widget_post.buffer.text)
      true
    end

    def start_post
      if not(frozen? or destroyed?)
        widget_post.editable = false
        [widget_post, widget_send].compact.each{|widget| widget.sensitive = false }
        widget_tool.sensitive = true
      end
    end

    def end_post
      if not(frozen? or destroyed?)
        @posting = nil
        widget_post.editable = true
        [widget_post, widget_send].compact.each{|widget| widget.sensitive = true } end end

    # ユーザによって投稿が中止された場合に呼ばれる
    def cancel_post
      if not(frozen? or destroyed?)
        if @options[:delegated_by]
          @options[:delegated_by].widget_post.buffer.text = widget_post.buffer.text
          destroy
        else
          end_post end end end

    def delegate(world: nil)
      if @options[:postboxstorage] && delegatable?
        options = {
          **all_options,
          delegate_other: false,
          delegated_by: self,
          target_world: world || target_world }
        if @options[:delegate_other].respond_to? :to_proc
          @options[:delegate_other].to_proc.(options)
        else
          @options[:postboxstorage].pack_start(Gtk::PostBox.new(nil, options)).show_all
        end
        true
      end
    end

    def service
      target_world
    end

    private def target_world
      @target_world || current_world
    end

    private def current_world
      world, = Plugin.filtering(:world_current, nil)
      world
    end

    # テキストが編集前と同じ状態なら真を返す。
    # ウィジェットが破棄されている場合は、常に真を返す
    def post_is_empty?
      widget_post.destroyed? or widget_post.buffer.text.empty? or widget_post.buffer.text == @header + @footer end

    def brothers
      if(@options[:postboxstorage])
        @options[:postboxstorage].children.find_all{|c| c.sensitive? }
      else
        [] end end

    def lonely?
      brothers.size <= 1 end

    # フォーカスが外れたことによって削除して良いなら真を返す。
    def destructible?
      if(@options.has_key?(:postboxstorage))
        return false if lonely? or (brothers - [self]).all?{ |w| !w.delegatable? }
        post_is_empty?
      else
        true end end

    # _related_widgets_ のうちどれもアクティブではなく、フォーカスが外れたら削除される設定の場合、このウィジェットを削除する
    def destroy_if_necessary(*related_widgets)
      if(not(frozen? or destroyed?) and not([widget_post, *related_widgets].compact.any?{ |w| w.focus? }) and destructible?)
        destroy
        true end end

    def on_delete
      if(block_given?)
        @on_delete = Proc.new
      elsif defined? @on_delete
        @on_delete.call end end

    def reply?
      !@to.empty? and !to_display_only? end

    def register
      @@ringlock.synchronize{
        @@postboxes << self } end

    # blind footer を投稿につけるかどうかを返す
    # ==== Return
    # TrueClass|FalseClass
    def use_blind_footer?
      @use_blind_footer end

    def update_remain_charcount
      remain_charcount.next{ |count|
        @remain.set_text((count || '---').to_s) if not @remain.destroyed?
      }.trap {
        @remain.set_text('---') if not @remain.destroyed?
      }
    end

    def remain_charcount
      if not widget_post.destroyed?
        Plugin[:gtk].spell(:remain_charcount, target_world, **compose_options)
      end
    end

    def focus_out_event(widget, event=nil)
      options = @options
      Delayer.new{
        if(not(frozen? or destroyed?) and not(options.has_key?(:postboxstorage)) and post_is_empty?)
          destroy_if_necessary(widget_send, widget_tool, *@reply_widgets) end }
      false end

    # Initialize Methods

    def get_backgroundcolor(message)
      if(message.from_me?)
        UserConfig[:mumble_self_bg]
      elsif(message.to_me?)
        UserConfig[:mumble_reply_bg]
      else
        UserConfig[:mumble_basic_bg] end end

    def get_backgroundstyle(message)
      style = Gtk::Style.new()
      color = get_backgroundcolor(message)
      [Gtk::STATE_ACTIVE, Gtk::STATE_NORMAL, Gtk::STATE_SELECTED, Gtk::STATE_PRELIGHT, Gtk::STATE_INSENSITIVE].each{ |state|
        style.set_bg(state, *color) }
      style end

    def post_set_default_text(post)
      if @options[:delegated_by]
        post.buffer.text = @options[:delegated_by].post.buffer.text
        @options[:delegated_by].post.buffer.text = ''
      elsif !(@header.empty? and @footer.empty?)
        post.buffer.text = @header + @footer
        post.buffer.place_cursor(post.buffer.get_iter_at_offset(@header.size)) end
      post.accepts_tab = false end

    # PostBoxを複製するときのために、このPostBoxを生成した時に指定された全ての名前付き引数と値のペアを返す
    # ==== Return
    # Hash
    def all_options
      { from: @from,
        to: @to,
        footer: @footer,
        to_display_only: to_display_only?,
        visibility: @visibility,
        **@options } end

    # compose Spellを呼び出す際のオプションを返す
    # ==== Return
    # Hash
    def compose_options
      text = widget_post.buffer.text
      text += UserConfig[:footer] if use_blind_footer?
      {
        body: text,
        visibility: @visibility
      }
    end

    # 真を返すなら、 @to の要素はPostBoxの下に表示するのみで、投稿時にリプライにしない
    # ==== Return
    # TrueClass|FalseClass
    def to_display_only?
      @to_display_only end

  end
end
