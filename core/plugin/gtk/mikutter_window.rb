# -*- coding: utf-8 -*-

require "gtk2"

class Gtk::MikutterWindow < Gtk::Window

  attr_reader :panes, :statusbar

  def initialize(*args)
    super
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

  # def set_focus(widget)
  #   if widget.is_a? Gtk::TimeLine
      
  #   end
  # end

  private

  # ステータスバーを返す
  # ==== Return
  # Gtk::Statusbar
  def create_statusbar
    statusbar = Gtk::Statusbar.new
    notice "statusbar: context id: #{statusbar.get_context_id("system")}"
    statusbar.push(statusbar.get_context_id("system"), "Twitterに新しい視野を、mikutter。")
    status_button = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get("settings.png"), 16, 16))
    status_button.relief = Gtk::RELIEF_NONE
    status_button.ssc(:clicked) {
      Plugin.call(:gui_setting) }
    @statusbar = statusbar.closeup(status_button) end
end
