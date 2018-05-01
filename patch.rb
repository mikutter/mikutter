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
      itv = Gtk::IntelligentTextview.new(message.to_show, 'font' => :mumble_basic_font)
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

