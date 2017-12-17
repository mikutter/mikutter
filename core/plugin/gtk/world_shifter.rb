# -*- coding: utf-8 -*-

require "gtk2"

class Gtk::WorldShifter < Gtk::EventBox
  UserConfig[:gtk_accountbox_geometry] ||= 32

  def initialize
    Plugin[:gtk].on_primary_service_changed(&method(:travel))
    super
    Plugin[:gtk].on_userconfig_modify do |key, newval|
      refresh if key == :world_shifter_visibility
    end
    Plugin[:gtk].on_service_registered do |service|
      refresh
    end
    Plugin[:gtk].on_service_destroyed do |service|
      refresh
    end
    ssc(:button_press_event) do |this,event|
      open_menu event if 3 >= event.button
      false
    end
    ssc_atonce(:realize) do
      travel Service.primary
    end
  end

  def refresh
    if visible?
      if not @face
        @face = Gtk::Image.new(Skin['loading.png'].pixbuf(width: UserConfig[:gtk_accountbox_geometry], height: UserConfig[:gtk_accountbox_geometry]))
        self.add(@face).show_all
      end
    else
      if @face
        self.remove(@face)
        @face.destroy
        @face = nil
      end
    end
  end

  def travel(world)
    refresh
    if @face
      transaction = @world_transaction = SecureRandom.uuid
      rect = { width:  UserConfig[:gtk_accountbox_geometry],
               height: UserConfig[:gtk_accountbox_geometry] }
      @face.pixbuf = world&.icon&.load_pixbuf(**rect) do |pixbuf|
        if transaction == @world_transaction
          @face.pixbuf = pixbuf
        end
      end || Skin['notfound.png'].pixbuf(**rect)
    end
  end

  def open_menu(event)
    @menu_last_services ||= Service.to_a.hash
    if @menu_last_services != Service.to_a.hash
      @menu.destroy if @menu
      @menu_last_services = @menu = nil end
    @menu ||= Gtk::Menu.new.tap do |menu|
      Enumerator.new{|y|
        Plugin.filtering(:worlds, y)
      }.each do |world|
        item = Gtk::ImageMenuItem.new(world.title, false)
        item.set_image Gtk::WebIcon.new(world.icon, UserConfig[:gtk_accountbox_geometry], UserConfig[:gtk_accountbox_geometry])
        item.ssc(:activate) { |w|
          Plugin.call(:world_change_current, world)
          false }
        menu.append item end
      menu end
    @menu.show_all.popup(nil, nil, event.button, event.time) end

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
end
