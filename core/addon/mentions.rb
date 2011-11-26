# -*- coding: utf-8 -*-
# mentions.rb
#
# Reply display/post support

Module.new do
  main = Gtk::TimeLine.new()
  image = Gtk::Image.new(Gdk::Pixbuf.new(MUI::Skin.get("reply.png"), 24, 24))

  plugin = Plugin::create(:mentions)
  plugin.add_event(:boot){ |service|
    # Plugin.call(:mui_tab_regist, main, 'Replies', MUI::Skin.get("reply.png"))
    Plugin.call(:mui_tab_regist, main, 'Replies', image)
    # Gtk::TimeLine.addwidgetrule(/@([a-zA-Z0-9_]+)/){ |text|
    #   user = User.findbyidname(text[1, text.size])
    #   Gtk::WebIcon.new(user[:profile_image_url], 12, 12) if user }
  }
  plugin.add_event(:mention){ |service, messages|
    # image.set_pixbuf(Gdk::Pixbuf.new(MUI::Skin.get("icon.png"), 24, 24))
    main.add(messages) }
  plugin.add_event(:favorite){ |service, fav_by, message|
    if UserConfig[:favorited_by_anyone_act_as_reply] and fav_by[:idname] != service.idname
      main.add(message)
      main.favorite(fav_by, message)
    end
  }

end
