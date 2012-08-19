# -*- coding: utf-8 -*-

require "gtk2"

class Gtk::MikutterWindow < Gtk::Window

  attr_reader :panes

  def initialize(*args)
    super
    @container = Gtk::VBox.new(false, 0)
    @panes = Gtk::HBox.new(true, 0)
    @postboxes = Gtk::VBox.new(false, 0)
    add(@container.closeup(@postboxes).pack_start(@panes).closeup(statusbar))
  end

  def add_postbox(i_postbox)
    postbox = Gtk::PostBox.new(i_postbox.poster || Service.primary, (i_postbox.options||{}).merge(:postboxstorage => @postboxes, :delegate_other => true))
    @postboxes.pack_start(postbox)
    set_focus(postbox.post)
    postbox.show_all end

  # ステータスバーを返す
  # ==== Return
  # Gtk::Statusbar
  def statusbar
    statusbar = Gtk::Statusbar.new
    statusbar.push(statusbar.get_context_id("system"), "Twitterに新しい視野を、mikutter。")
    status_button = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get("settings.png"), 16, 16))
    status_button.relief = Gtk::RELIEF_NONE
    status_button.ssc(:clicked) {
      Plugin.call(:gui_setting) }
    statusbar.closeup(status_button) end
  memoize :statusbar


end
