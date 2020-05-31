# -*- coding: utf-8 -*-
module Plugin::Extract
end

=begin rdoc
  抽出タブの一覧
=end

class Plugin::Extract::ExtractTabList < ::Gtk::TreeView
  ICON_SIZE = 16

  COL_ICON  = 0
  COL_NAME  = 1
  COL_SLUG  = 2
  COL_SOUND = 3
  COL_POPUP = 4

  def initialize(plugin)
    super(Gtk::ListStore.new(
            GdkPixbuf::Pixbuf, # icon
            String,            # name
            Symbol,            # slug
            GdkPixbuf::Pixbuf, # sound
            GdkPixbuf::Pixbuf  # popup
          ))

    append_column Gtk::TreeViewColumn.new(
                    '',
                    Gtk::CellRendererPixbuf.new,
                    pixbuf: COL_ICON
                  )
    append_column Gtk::TreeViewColumn.new(
                    plugin._('名前'),
                    Gtk::CellRendererText.new,
                    text: COL_NAME
                  ).tap { |col| col.expand = true }
    append_column Gtk::TreeViewColumn.new(
                    '',
                    Gtk::CellRendererPixbuf.new,
                    pixbuf: COL_SOUND
                  )
    append_column Gtk::TreeViewColumn.new(
                    '',
                    Gtk::CellRendererPixbuf.new,
                    pixbuf: COL_POPUP
                  )

    extract_tabs.each(&method(:add_record))
    register_signal_handlers

    Plugin[:extract].on_userconfig_modify do |key, value|
      next if key != :extract_tabs
      model.clear
      extract_tabs.each(&method(:add_record))
    end
  end

  # 現在選択されている抽出タブのslugを返す
  # ==== Return
  # 選択されている項目のslug。何も選択されていない場合はnil
  def selected_slug
    selected_iter = selection.selected
    selected_iter[COL_SLUG].to_sym if selected_iter
  end

  # レコードを追加する
  # ==== Args
  # [record] 追加するレコード(Plugin::Extract::Setting)
  # ==== Return
  # self
  def add_record(record)
    iter = model.append
    setup_iter iter, record
    self
  end

  # レコードをもとにリストビューを更新する
  # ==== Args
  # [record] 更新されたレコード(Plugin::Extract::Setting)
  def update_record(record)
    update_iter = model.to_enum
                    .map { |_, _, iter| iter }
                    .find { |iter| iter[COL_SLUG].to_sym == record[:slug] }
    setup_iter update_iter, record if update_iter
  end

  # 抽出タブをリストから削除する
  # ==== Args
  # [record_slug] 削除する抽出タブのslug
  # ==== Return
  # self
  def remove_record(record_slug)
    record_slug = record_slug.to_sym
    remove_iter = model.to_enum(:each).map{|_,_,iter|iter}.find{|iter| record_slug == iter[COL_SLUG].to_sym }
    model.remove(remove_iter) if remove_iter
    self end

  private

  def register_signal_handlers
    # 項目をダブルクリックして設定を開く
    ssc(:button_press_event) do |_, ev|
      next if ev.event_type != Gdk::Event::BUTTON2_PRESS
      slug = selected_slug
      if slug
        Plugin.call(:extract_open_edit_dialog, slug)
        true
      end
    end
  end

  # ==== utility

  # レコードの配列を返す
  # ==== Return
  # レコードの配列
  def extract_tabs
    Plugin.filtering(:extract_tabs_get, []).first
  end

  # イテレータにレコードの内容をコピーする
  # ==== Args
  # [iter] TreeIter
  # [record] 参照するレコード (Plugin::Extract::Setting)
  def setup_iter(iter, record)
    size = { width: Gdk.scale(ICON_SIZE), height: Gdk.scale(ICON_SIZE) }
    set_icon = ->(col, photo) do
      iter[col] = photo.load_pixbuf(**size) do |pb|
        iter[col] = pb unless destroyed?
      end
    end

    iter[COL_NAME] = record[:name]
    iter[COL_SLUG] = record[:slug]
    if record[:icon]
      photo = Enumerator.new do |y|
        Plugin.filtering :photo_filter, record[:icon], y
      end.first
      set_icon.(COL_ICON, photo)
    end
    if record[:sound].to_s.empty?
      set_icon.(COL_SOUND, Skin[:notify_sound_off])
    else
      set_icon.(COL_SOUND, Skin[:notify_sound_on])
    end
    if record[:popup]
      set_icon.(COL_POPUP, Skin[:notify_popup_on])
    else
      set_icon.(COL_POPUP, Skin[:notify_popup_off])
    end
  end

end
