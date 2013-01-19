# -*- coding: utf-8 -*-

require "gtk2"
p File.expand_path(File.join(File.dirname(__FILE__), 'toolbar_generator'))
require File.expand_path(File.join(File.dirname(__FILE__), 'toolbar_generator'))

class Gtk::MikutterWindow < Gtk::Window

  attr_reader :panes, :statusbar

  def initialize(imaginally, *args)
    super(*args)
    @imaginally = imaginally
    @container = Gtk::VBox.new(false, 0)
    @panes = Gtk::HBox.new(true, 0)
    @postboxes = Gtk::VBox.new(false, 0)
    add(@container.closeup(@postboxes).pack_start(@panes).closeup(create_statusbar))
  end

  def add_postbox(i_postbox)
    postbox = Gtk::PostBox.new(i_postbox.poster || Service.primary, {postboxstorage: @postboxes, delegate_other: true}.merge(i_postbox.options||{}))
    @postboxes.pack_start(postbox)
    set_focus(postbox.post)
    postbox.show_all end

  private

  # ステータスバーを返す
  # ==== Return
  # Gtk::Statusbar
  def create_statusbar
    statusbar = Gtk::Statusbar.new
    notice "statusbar: context id: #{statusbar.get_context_id("system")}"
    statusbar.push(statusbar.get_context_id("system"), "mikutterの誕生以来、最も大きな驚きを")
    @statusbar = statusbar.closeup(status_button(Gtk::HBox.new)) end

  # ステータスバーに表示するWindowレベルのボタンを _container_ にpackする。
  # 返された時点では空で、後からボタンが入る(showメソッドは自動的に呼ばれる)。
  # ==== Args
  # [container] packするコンテナ
  # ==== Return
  # container
  def status_button(container)
    Plugin::Gtk::ToolbarGenerator.generate(container,
                                           Plugin::GUI::Event.new(:window_toolbar, @imaginally, []),
                                           :window) end

end
