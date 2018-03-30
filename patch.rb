class Gtk::PostBox
  # @toのアクセサを生やす
  def worldon_get_reply_to
    @to&.first
  end

  alias generate_box_worldon generate_box
  # 返信時にPlugin::Worldon::Statusに対してもIntelligentTextviewを生やす
  def generate_box
    vbox = generate_box_worldon
    @to.select{|m| m.is_a?(Plugin::Worldon::Status) }.each{|message|
      w_reply = Gtk::HBox.new
      itv = Gtk::IntelligentTextview.new(message.description_plain, 'font' => :mumble_basic_font)
      itv.style_generator = lambda{ get_backgroundstyle(message) }
      itv.bg_modifier
      ev = Gtk::EventBox.new
      ev.style = get_backgroundstyle(message)
      vbox.closeup(ev.add(w_reply.closeup(Gtk::WebIcon.new(message.user.icon, 32, 32).top).add(itv)))
      @reply_widgets << itv
    }
    vbox
  end
end

# Plugin::Worldon::Statusの場合、<a>タグが付かないようにto_showではなくdescription_plainを呼ぶ。
class Gdk::SubPartsMessageBase < Gdk::SubParts
  def main_message(message, context = dummy_context)
    show_text = message.to_show
    if message.is_a?(Plugin::Worldon::Status)
      show_text = message.description_plain
    end
    attr_list, text = Pango.parse_markup(Pango.escape(show_text))
    layout = context.create_pango_layout
    layout.width = (width - icon_width - margin*3 - edge*2) * Pango::SCALE
    layout.attributes = attr_list
    layout.wrap = Pango::WrapMode::CHAR
    layout.font_description = default_font
    layout.text = text
    layout
  end
end

# fileselect DSLにshortcutsオプションを足す
module Gtk::FormDSL
  def fileselect(label, config, _current=Dir.pwd, dir: _current, title: label.to_s, shortcuts: nil)
    fsselect(label, config, dir: dir, action: Gtk::FileChooser::ACTION_OPEN, title: title, shortcuts: shortcuts)
  end

  def dirselect(label, config, _current=Dir.pwd, dir: _current, title: label.to_s, shortcuts: nil)
    fsselect(label, config, dir: dir, action: Gtk::FileChooser::ACTION_SELECT_FOLDER, title: title, shortcuts: shortcuts)
  end

  def fsselect(label, config, dir: Dir.pwd, action: Gtk::FileChooser::ACTION_OPEN, title: label, shortcuts: nil)
    container = input(label, config)
    input = container.children.last.children.first
    button = Gtk::Button.new(Plugin[:settings]._('参照'))
    container.pack_start(button, false)
    button.signal_connect(:clicked, &gen_fileselect_dialog_generator(title, action, dir, config: config, shortcuts: shortcuts, &input.method(:text=)))
    container
  end

  def gen_fileselect_dialog_generator(title, action, dir, config:, shortcuts: nil, &result_callback)
    ->(widget) do
      dialog = Gtk::FileChooserDialog.new(title,
                                          widget.get_ancestor(Gtk::Window),
                                          action,
                                          nil,
                                          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                          [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
      dialog.current_folder = File.expand_path(dir)
      shortcuts.to_a.select { |dir|
        !dialog.shortcut_folders.include?(dir)
      }.each { |dir|
        begin
          dialog.add_shortcut_folder(dir)
        rescue => e
          puts e
          puts e.backtrace
        end
      }
      dialog.ssc_atonce(:response, &gen_fs_dialog_response_callback(config, &result_callback))
      dialog.show_all
      false
    end
  end
end

