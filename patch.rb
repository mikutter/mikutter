class Gtk::PostBox
  def worldon_get_reply_to
    @to&.first
  end

  alias generate_box_org generate_box

  def generate_box
    vbox = generate_box_org
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

class Gdk::SubPartsMessageBase < Gdk::SubParts
  def main_message(message, context = dummy_context)
    attr_list, text = Pango.parse_markup(Pango.escape(message.description_plain))
    layout = context.create_pango_layout
    layout.width = (width - icon_width - margin*3 - edge*2) * Pango::SCALE
    layout.attributes = attr_list
    layout.wrap = Pango::WrapMode::CHAR
    layout.font_description = default_font
    layout.text = text
    layout
  end
end

