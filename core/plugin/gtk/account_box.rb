# -*- coding: utf-8 -*-

require "gtk2"

class Gtk::AccountBox < Gtk::EventBox
  UserConfig[:gtk_accountbox_geometry] = 32

  def initialize
    @face = Gtk::Image.new(Gdk::WebImageLoader.loading_pixbuf(UserConfig[:gtk_accountbox_geometry], UserConfig[:gtk_accountbox_geometry]))
    Plugin[:gtk].on_primary_service_changed(&method(:change_user))
    change_user Service.primary
    super
    ssc(:button_press_event) do |this,event|
      open_menu event if 3 >= event.button
      false
    end
    self.add(@face) end
  
  def change_user(service)
    user = service.user_obj
    @face.pixbuf = Gdk::WebImageLoader.pixbuf(user[:profile_image_url], UserConfig[:gtk_accountbox_geometry], UserConfig[:gtk_accountbox_geometry]){ |pixbuf|
      if user == service.user_obj
        @face.pixbuf = pixbuf end } end

  def open_menu(event)
    menu = Gtk::Menu.new
    Service.all.each do |service|
      item = Gtk::ImageMenuItem.new(service.user, false)
      item.set_image Gtk::WebIcon.new(service.user_obj[:profile_image_url], UserConfig[:gtk_accountbox_geometry], UserConfig[:gtk_accountbox_geometry])
      item.ssc(:activate) { |w|
        Service.set_primary(service)
        false }
      menu.append item end
    menu.show_all.popup(nil, nil, event.button, event.time) end
end
