# -*- coding: utf-8 -*-

module Plugin::Gtk
  class SlugDictionary
    class << self
      # 名前に対するGtkクラスのハッシュを返す
      def nameklass
        @nameklass ||= {} end

      # 新しいウィジェットタイプ _name_ を登録する。
      # ==== Args
      # [name] ウィジェットのタイプ(Class)
      # [gtk_klass] クラス(Class)
      def register_widget(name, gtk_klass)
        type_strict name => Class, gtk_klass => Class
        nameklass[name] = gtk_klass
      end
    end

    register_widget Plugin::GUI::Window,         ::Gtk::MikutterWindow
    register_widget Plugin::GUI::Pane,           ::Gtk::Notebook
    register_widget Plugin::GUI::Tab,            ::Gtk::EventBox
    register_widget Plugin::GUI::TabToolbar,     ::Gtk::TabToolbar
    register_widget Plugin::GUI::Timeline,       ::Gtk::TimeLine
    register_widget Plugin::GUI::Cluster,        ::Gtk::Notebook
    register_widget Plugin::GUI::Fragment,     ::Gtk::EventBox
    register_widget Plugin::GUI::TabChildWidget, ::Gtk::TabContainer
    register_widget Plugin::GUI::Postbox,        ::Gtk::PostBox

    def initialize
      @widget_of_gtk = Hash.new{|h, k|
        if Plugin::Gtk::SlugDictionary.nameklass.has_key?(k)
          h[k] = {}
        else
          raise UndefinedWidgetError, "widget type `#{k}' does not exists" end } end

    # _i_widget_ に対応するGtkウィジェットが _gtk_widget_ であることを登録する
    # ==== Args
    # [i_widget] Plugin::GUI::Widget
    # [gtk_widget] Gtk::Widget
    # ==== Return
    # self
    def add(i_widget, gtk_widget)
      @widget_of_gtk[i_widget.class][i_widget.slug] = gtk_widget end

    # _i_widget_ の登録を解除する
    # ==== Args
    # [i_widget] Plugin::GUI::Widget
    # ==== Return
    # self
    def remove(i_widget)
     @widget_of_gtk[i_widget.class].remove(i_widget.slug)
    end

    # ウィジェットに対するGtkウィジェットを返す
    # ==== Args
    # [klass_or_i_widget] ウィジェットかクラス名
    # [slug] 第一引数にウィジェットのクラスを指定した場合、そのスラッグ
    # ==== Return
    # Gtkウィジェット
    def get(klass_or_i_widget, slug=nil)
      if klass_or_i_widget.is_a? Plugin::GUI::Widget
        @widget_of_gtk[klass_or_i_widget.class][klass_or_i_widget.slug]
      else
        @widget_of_gtk[klass_or_i_widget][slug] end end

    # _klass_ クラスのウィジェットを列挙する
    # ==== Args
    # [klass] クラス(Plugin::GUI::Postboxなど)
    # ==== Return
    # [Enumerable] そのクラスのインスタンスのうち、このSlugDictionaryが管理しているものを列挙するEnumerable
    def widgets(klass)
      @widget_of_gtk[klass].values
    end

    # _gtk_widget_ に対応する内部表現のウィジェットをかえす。逆引きなので非効率、あまり使わないこと。
    # ==== Args
    # [gtk_widget] Gtkウィジェットのインスタンス
    # ==== Return
    # 対応するウィジェット、または存在しない場合はnil
    def imaginally_by_gtk(gtk_widget)
      type_strict gtk_widget => ::Gtk::Widget
      Plugin::Gtk::SlugDictionary.nameklass.each{ |i_widget_klass, gtk_widget_klass|
        if gtk_widget.is_a? gtk_widget_klass
          next if not i_widget_klass
          slug = @widget_of_gtk[i_widget_klass].key(gtk_widget)
          next if not slug
          if i_widget_klass.exist?(slug)
            return i_widget_klass.instance(slug) end end }
      error "not found (#{gtk_widget.inspect})"
      nil end

    class UndefinedWidgetError < ArgumentError
    end

  end
end



