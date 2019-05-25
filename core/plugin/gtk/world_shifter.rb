# -*- coding: utf-8 -*-

require "gtk2"

class Gtk::WorldShifter < Gtk::EventBox
  UserConfig[:gtk_accountbox_geometry] ||= 32

  def initialize
    super
    ssc(:button_press_event) do |this,event|
      open_menu event if 3 >= event.button
      false
    end
    ssc_atonce(:realize) do
      refresh
    end
    pluggaloid_event_listener
  end

  def refresh
    destroy_menu
    put_face
    modify_face
  end

  def open_menu(event)
    @menu ||= Gtk::Menu.new.tap do |menu|
      Enumerator.new{|y|
        Plugin.filtering(:worlds, y)
      }.each do |world|
        item = Gtk::ImageMenuItem.new(world.title, false)
        item.set_image Gtk::WebIcon.new(world.icon, UserConfig[:gtk_accountbox_geometry], UserConfig[:gtk_accountbox_geometry])
        item.ssc(:activate) { |w|
          Plugin.call(:world_change_current, world)
          @face.tooltip(world.title)
          false }
        menu.append item
      end
      menu.append Gtk::SeparatorMenuItem.new
      item = Gtk::ImageMenuItem.new(Plugin[:gtk]._('Worldを追加'), false)
      item.set_image Gtk::WebIcon.new(Skin[:add], UserConfig[:gtk_accountbox_geometry], UserConfig[:gtk_accountbox_geometry])
      item.ssc(:activate) { |w|
        Plugin.call(:request_world_add)
        false }
      menu.append item
      menu
    end
    @menu.show_all.popup(nil, nil, event.button, event.time)
  end

  def destroy_menu
    @menu&.destroy
    @menu = nil
  end

  def pluggaloid_event_listener
    tag = Plugin[:gtk].handler_tag(:world_shifter) do
      Plugin[:gtk].on_world_change_current{ refresh }
      Plugin[:gtk].on_userconfig_modify do |key, newval|
        refresh if key == :world_shifter_visibility
      end
      Plugin[:gtk].on_world_reordered do |_worlds|
        refresh
      end
      Plugin[:gtk].on_world_after_created do |world|
        refresh
      end
      Plugin[:gtk].on_world_destroy do |world|
        refresh
      end
    end
    ssc(:destroy) do
      Plugin[:gtk].detach(tag)
    end
  end

  def put_face
    if visible?
      add_face_widget_ifn
    else
      remove_face_widget_ifn
    end
  end

  def visible?
    case UserConfig[:world_shifter_visibility]
    when :always
      true
    when :auto
      1 < Enumerator.new{|y| Plugin.filtering(:worlds, y) }.take(2).to_a.size
    else
      false
    end
  end

  def modify_face
    if @face
      world, = Plugin.filtering(:world_current, nil)
      transaction = @world_transaction = SecureRandom.uuid
      rect = { width:  UserConfig[:gtk_accountbox_geometry]*scale,
               height: UserConfig[:gtk_accountbox_geometry]*scale }
      @face.pixbuf = world&.icon&.load_pixbuf(**rect) do |pixbuf|
        if transaction == @world_transaction
          @face.pixbuf = pixbuf
        end
      end || Skin[:add].pixbuf(**rect)
    end
  end

  def add_face_widget_ifn
    if not @face
      @face = Gtk::Image.new(Skin[:loading].pixbuf(width: UserConfig[:gtk_accountbox_geometry]*scale, height: UserConfig[:gtk_accountbox_geometry]*scale))
      self.add(@face).show_all
    end
    world, = Plugin.filtering(:world_current, nil)
    if world
      @face.tooltip(world.title)
    end
  end

  def remove_face_widget_ifn
    if @face
      self.remove(@face)
      @face.destroy
      @face = nil
    end
  end

  def scale
    case UserConfig[:ui_scale]
    when :auto
      Gdk::Visual.system.screen.resolution / 100
    else
      UserConfig[:ui_scale]
    end
  end
end
