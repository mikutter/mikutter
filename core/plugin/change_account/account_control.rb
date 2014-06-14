# -*- coding: utf-8 -*-
module ::Plugin::ChangeAccount
  class AccountControl < Gtk::CRUD
    include Gtk::TreeViewPrettyScroll
    COL_ICON = 0
    COL_SCREEN_NAME = 1
    COL_NAME = 2
    COL_SERVICE = 3

    def column_schemer
      [{:kind => :pixbuf, :type => Gdk::Pixbuf, :label => ''},
       {:kind => :text, :type => String, :label => Plugin[:change_account]._('SN')},
       {:kind => :text, :type => String, :label => Plugin[:change_account]._('名前')},
       {:type => Object},
      ].freeze
    end

    def force_record_create(service)
      type_strict service => Service
      return if self.destroyed?
      [service.user_obj[:name], service.user_obj[:idname], service]
      iter = model.model.append
      iter[COL_ICON] = Gdk::WebImageLoader.pixbuf(service.user_obj[:profile_image_url], 16, 16) { |new_pixbuf|
        iter[COL_ICON] = new_pixbuf if not self.destroyed? }
      iter[COL_SCREEN_NAME] = service.user_obj[:idname]
      iter[COL_NAME] = service.user_obj[:name]
      iter[COL_SERVICE] = service
      on_created(iter)
    end

    def on_deleted(iter)
      Service.destroy(iter[COL_SERVICE]) end

    def popup_input_window(defaults = [])
      parent_window = self and self.toplevel.toplevel? and self.toplevel
      twitter = MikuTwitter.new
      twitter.consumer_key = Environment::TWITTER_CONSUMER_KEY
      twitter.consumer_secret = Environment::TWITTER_CONSUMER_SECRET
      request_token = twitter.request_oauth_token
      result = nil
      dialog = ::Gtk::Dialog.new("#{dialog_title} - " + Environment::NAME)
      dialog.set_size_request(640, 480)
      dialog.window_position = Gtk::Window::POS_CENTER

      container = ::Gtk::VBox.new
      code_input = ::Gtk::Entry.new
      code_input.text = ""
      code_input.signal_connect('activate') { |elm|
        dialog.response(::Gtk::Dialog::RESPONSE_OK) }
      container.add(::Gtk::IntelligentTextview.new(request_token.authorize_url))
      container.closeup(code_input.center)
      dialog.vbox.pack_start(container, true, true, 30)

      dialog.add_button(::Gtk::Stock::OK, ::Gtk::Dialog::RESPONSE_OK)
      dialog.add_button(::Gtk::Stock::CANCEL, ::Gtk::Dialog::RESPONSE_CANCEL)
      dialog.signal_connect('response'){ |widget, response|
        if response == ::Gtk::Dialog::RESPONSE_OK
          access_token = request_token.get_access_token(oauth_token: request_token.token,
                                                        oauth_verifier: code_input.text)
          dialog.sensitive = false
          Service.add_service(access_token.token, access_token.secret).next { |service|              result = service
            parent_window.sensitive = true
            dialog.hide_all.destroy
            Gtk::main_quit
          }.trap { |e|
            alert = ::Gtk::Dialog.new(Plugin[:change_account]._("エラー - %{name}") % {name: Environment::NAME})
            alert.set_size_request(420, 90)
            alert.window_position = ::Gtk::Window::POS_CENTER
            alert.vbox.add(::Gtk::Label.new(e.to_s))
            alert.add_button(::Gtk::Stock::OK, ::Gtk::Dialog::RESPONSE_OK)
            alert.show_all
            alert.signal_connect('response'){
              dialog.sensitive = true
              alert.hide_all.destroy }
          }.terminate
        else
          result = nil
          parent_window.sensitive = true
          dialog.hide_all.destroy
          Gtk::main_quit
        end
      }
      parent_window.sensitive = false
      dialog.show_all
      Gtk::main
      result
    end
  end
end
