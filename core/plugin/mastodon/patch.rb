class Gtk::PostBox
  # @toのアクセサを生やす
  def mastodon_get_reply_to
    @to&.first
  end
end

