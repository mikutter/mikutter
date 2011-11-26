# -*- coding: utf-8 -*-

miquire :core, 'plugin'

module Addon

  def self.regist_tab(container, label, image=nil)
    Plugin.call(:mui_tab_regist, container, label, image) end

  def self.remove_tab(label)
    Plugin.call(:mui_tab_remove, label) end

  def self.focus(label)
    Plugin.call(:mui_tab_active, label) end

  def self.gen_tabclass
    Class.new(gen_tab_base_class) do
      define_method(:on_create) do
        self.class.tabs.push(self) end

      define_method(:on_remove) do
        self.class.tabs.delete(self) end

      def icon
        @options[:icon] end

      def actual_name
        (@name or '') + suffix end

      def suffix
        '' end

      def self.tabs
        @tabs = [] if not @tabs
        @tabs end end end

  def self.gen_tab_base_class
    Class.new do
      attr_reader :name, :tab, :timeline, :header, :options
      attr_accessor :mark

      def initialize(name, service, options = {})
        @name, @service, @options = name, service, options
        @tab, @mark, @destroyed = gen_main, true, false
        Addon.regist_tab(@tab, actual_name, icon)
        on_create end

      # Messageをタイムラインに追加する
      # ==== Args
      # [msgs]
      #   Message のインスタンスか、複数の Message が入った配列
      def update(msgs)
        unless destroyed?
          @timeline.add(msgs) end end

      def remove
        on_remove
        @destroyed = true
        Addon.remove_tab(actual_name) end

      def focus
        Addon.focus(actual_name) end

      def destroyed?
        @timeline.destroyed? or @destroyed end

      private

      def gen_main
        @timeline = Gtk::TimeLine.new
        @header = (@options[:header] or Gtk::HBox.new)
        Gtk::VBox.new(false, 0).closeup(@header).add(@timeline) end end end

=begin rdoc
  コマンド関連のユーティリティ
=end
  module Command

    # キー _key_ に関連付けられたコマンドを全て実行する。
    # コマンドを一つでも実行したらtrueを返す
    def self.call_keypress_event(key, defaults = {})
      tl, active_mumble, miracle_painter, postbox, valid_roles = tampr(defaults)
      executed = false
      keybinds = (UserConfig[:shortcutkey_keybinds] || Hash.new)
      commands = lazy{ Plugin.filtering(:command, Hash.new).first }
      options = generate_options(tl, active_mumble, miracle_painter, postbox)
      keybinds.values.each{ |behavior|
        if behavior[:key] == key
          cmd = commands[behavior[:slug]]
          if cmd and role_executable?(valid_roles, cmd[:role])
            option = role_argument(cmd[:role], options)
            if cmd[:condition] === option
              executed = true
              cmd[:exec].call(option) end end end }
      executed end

    # currentのRoleでexecutableのロールが実行できるかを返す。
    def self.role_executable?(current, executable)
      type_strict current => tcor(Enumerable, Set)
      if(executable.is_a? Enumerable or executable.is_a? Set)
        not (current & executable).empty?
      else
        current.include? executable end end

    def self.role_argument(role, options)
      type_strict options => Hash
      if(role.respond_to? :each)
        result = {}
        role.each{|x| result[x] = options[x] }
        result
      else
        options[role] end end

    def self.generate_options(tl, active_mumble, miracle_painter, postbox)
      arg = Gdk::MiraclePainter::Event.new(nil, active_mumble, tl, miracle_painter)
      { :message => arg,
        :message_select => arg,
        :messages => Gtk::TimeLine.get_active_mumbles.map{ |m|
          Gdk::MiraclePainter::Event.new(nil, m, tl, lazy{ tl.cell_renderer_message.miracle_painter(m) })},
        :timeline => tl,
        :postbox => postbox } end

    # 有効なロールを返す。
    # :timeline Gtk::TimeLineがアクティブであるなら
    # :message active_mumbleとmiracle_painterが真なら
    # :message_select :messageが真であり、なおかつつぶやきのテキストが選択状態であるなら
    # :postbox postboxがアクティブであるなら
    def self.get_valid_roles(focus, tl, active_mumble, miracle_painter, postbox)
      valid_roles = Set.new
      if postbox
        valid_roles << :postbox
      else
        if focus.is_a?(Gtk::TimeLine::InnerTL)
          if tl
            valid_roles << :timeline end
          if active_mumble and miracle_painter
            valid_roles << :message << :messages
            if tl.cell_renderer_message.miracle_painter(active_mumble).textselector_range
              valid_roles << :message_select end end end end
      valid_roles.freeze
    end

    # _tl_ , _active_mumble_ , _miracle_painter_ , _postbox_ , _roles_ の6つの値を返す。
    # 酷いメソッドである
    # *tl* 現在フォーカスされているタイムライン(Gtk::TimeLine::InnerTL)
    # *active_mumble* 選択されているメッセージ（代表一つ）(Message)
    # *miracle_painter* _active_mumble_ のレンダー(Gdk::MiraclePainter)
    # *postbox* 現在フォーカスされているPostBox(Gtk::PostBox)
    # *roles* 実行してもよいコマンドのロールのリスト
    def self.tampr(defaults={})
      t, a, m, p, r = tampr = _tampr(defaults)
      type_strict t => (t and Gtk::TimeLine::InnerTL), a => (a and Message), m => (m and Gdk::MiraclePainter), p => (p and Gtk::PostBox), r => (r and Set)
      tampr
    end

    def self._tampr(defaults={})
      type_strict defaults => Hash
      focus = defaults[:focus] || Plugin.filtering(:get_windows, []).first.first.focus
      tl = defaults[:tl] || Gtk::TimeLine::InnerTL.current_tl
      active_mumble = defaults[:message] || Gtk::TimeLine.get_active_mumbles.to_a.first
      miracle_painter = defaults[:miracle_painter] || ((active_mumble and tl) ? tl.cell_renderer_message.miracle_painter(active_mumble) : false)
      postbox = defaults[:postbox] || (focus ? focus.get_ancestor(Gtk::PostBox) : false)
      postbox = false if not postbox.is_a?(Gtk::PostBox)
      [tl, active_mumble, miracle_painter, postbox, get_valid_roles(focus, tl, active_mumble, miracle_painter, postbox)].freeze
    end

  end

end

# miquire :addon
# miquire :user_plugin
# ~> -:2: undefined method `miquire' for main:Object (NoMethodError)
