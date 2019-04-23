class Gtk::PostBox
  # @toのアクセサを生やす
  def worldon_get_reply_to
    @to&.first
  end
end

