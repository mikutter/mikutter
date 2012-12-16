# -*- coding: utf-8 -*-

class Gtk::TabToolbar < Gtk::HBox
  def initialize(imaginally, *args)
    type_strict imaginally => Plugin::GUI::TabToolbar
    @imaginally = imaginally
    super(*args)
    initialize_event
  end

  private

  # イベントハンドラの登録
  def initialize_event
    event = Plugin::GUI::Event.new(:tab_toolbar, @imaginally.parent, [])
    Thread.new{
      Plugin.filtering(:command, {}).first.values.select{ |command|
        command[:icon] and command[:role] == :tab and command[:condition] === event }
    }.next{ |commands|
      commands.each{ |command|
        face = command[:show_face] || command[:name] || command[:slug].to_s
        name = if defined? face.call then lambda{ |x| face.call(event) } else face end
        toolitem = Gtk::Button.new
        toolitem.add(Gtk::WebIcon.new(command[:icon], 16, 16))
        toolitem.tooltip(name)
        toolitem.ssc(:clicked){
          command[:exec].call(event) }
        closeup(toolitem) }
      show_all if not commands.empty?
    }.trap{ |e|
      error "error on command toolbar:"
      error e
    }.terminate("コマンドエラー")
  end
end
