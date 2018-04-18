# -*- coding: utf-8 -*-

require "gtk2"
require_relative 'toolbar_generator'
require_relative 'world_shifter'

class Gtk::MikutterWindow < Gtk::Window

  attr_reader :panes, :statusbar

  def initialize(imaginally, plugin, *args)
    type_strict plugin => Plugin
    super(*args)
    @imaginally = imaginally
    @plugin = plugin
    @container = Gtk::VBox.new(false, 0)
    @panes = Gtk::HBox.new(true, 0)
    header = Gtk::HBox.new(false, 0)
    @postboxes = Gtk::VBox.new(false, 0)
    add @container.
      closeup(header.
                closeup(Gtk::WorldShifter.new).
                pack_start(@postboxes)).
      pack_start(@panes).
      closeup(create_statusbar)
    Plugin[:gtk].on_userconfig_modify do |key, newval|
      if key == :postbox_visibility
        refresh
      end
    end
    Plugin[:gtk].on_world_after_created do |new_world|
      refresh end
    Plugin[:gtk].on_world_destroy do |deleted_world|
      refresh end
  end

  def add_postbox(i_postbox)
    options = {postboxstorage: @postboxes, delegate_other: true}.merge(i_postbox.options||{})
    if options[:delegate_other]
      i_window = i_postbox.ancestor_of(Plugin::GUI::Window)
      options[:delegate_other] = postbox_delegation_generator(i_window) end
    postbox = Gtk::PostBox.new(options)
    @postboxes.pack_start(postbox)
    set_focus(postbox.post) unless options[:delegated_by]
    postbox.no_show_all = false
    postbox.show_all if visible?
    postbox end

  private

  def postbox_delegation_generator(window)
    ->(params) do
      postbox = Plugin::GUI::Postbox.instance
      postbox.options = params
      window << postbox end end

  def refresh
    @postboxes.children.each(&(visible? ? :show_all : :hide))
  end

  # ステータスバーを返す
  # ==== Return
  # Gtk::Statusbar
  def create_statusbar
    statusbar = Gtk::Statusbar.new
    statusbar.push(statusbar.get_context_id("system"), @plugin._("Statusbar default message"))
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

  def visible?
    case UserConfig[:postbox_visibility]
    when :always
      true
    when :auto
      !!Enumerator.new{|y| Plugin.filtering(:worlds, y) }.first
    else
      false
    end
  end

end
