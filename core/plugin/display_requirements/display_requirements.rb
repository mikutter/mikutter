# -*- coding: utf-8 -*-

Plugin.create :display_requirements do
  BIRD_URL = "http://mikutter.hachune.net/img/twitter-bird.png".freeze
  CACHE_DIR = File.expand_path(File.join(Environment::CACHE, 'dr'))
  BIRD_CACHE_PATH = File.join(CACHE_DIR, "twitter-bird.png")

  on_gui_timeline_join_tab do |i_timeline, i_tab|
    i_tab.shrink
    fuckingbird = Gtk::Button.new
    fuckingbird.relief = Gtk::RELIEF_NONE
    fuckingbird.add(Gtk::WebIcon.new(BIRD_URL, 32, 32))
    fuckingbird.ssc(:clicked){ Gtk.openurl("https://twitter.com/") }
    i_tab.nativewidget(fuckingbird)
    i_tab.expand
  end

  on_image_cache_saved do |url, imagedata|
    begin
      if BIRD_URL == url and not FileTest.exist?(BIRD_CACHE_PATH)
        FileUtils.mkdir_p(CACHE_DIR)
        file_put_contents BIRD_CACHE_PATH, imagedata
      end
    rescue => exception
      # ここにmikutterをクラッシュさせようとする厄介がおるじゃろ
      # 　　(＾ω＾)
      #  ⊃exception⊂
      #
      # こうして…
      # 　　(＾ω＾)
      # 　 ⊃cepti⊂
      # 　　　:･..
      #
      # こうじゃ
      # 　　(＾ω＾)
      # 　　 ⊃⊂
      # 　　　:･:･
      # 　　 ':.･..
      warn exception
    end
  end

  filter_image_cache do |url, image, &stop|
    if BIRD_URL == url and FileTest.exist?(BIRD_CACHE_PATH)
      stop.call([url, file_get_contents(BIRD_CACHE_PATH)]) end
    [url, image] end

  filter_entity_linkrule_added do |options|
    EventFilter.cancel! if :search_hashtag == options[:filter_id]
    [options] end

  # いいね
  filter_skin_get do |filename, fallback_dirs|
    case filename
    when 'fav.png'
      filename = 'like.png'
    when 'unfav.png'
      filename = 'dont_like.png' end
    [filename, fallback_dirs] end

  filter_command do |menu|
    menu.delete(:favorite)
    menu.delete(:delete_favorite)
    [menu]
  end

  command(:like,
          name: _('いいねいいねする'),
          condition: Plugin::Command[:CanFavoriteAny],
          visible: true,
          icon: Skin['dont_like.png'],
          role: :timeline) do |opt|
    opt.messages.select(&:favoritable?).reject{ |m| m.favorited_by_me? Service.primary }.each(&:favorite) end

  command(:delete_like,
          name: _('あんいいね'),
          condition: Plugin::Command[:IsFavoritedAll],
          visible: true,
          icon: Skin['like.png'],
          role: :timeline) do |opt|
    opt.messages.each(&:unfavorite) end

  defactivity :like, _("いいね")
  defactivity :dont_like, _("あんいいね")

  on_favorite do |service, user, message|
    activity(:like, "#{message.user[:idname]}: #{message.to_s}",
             description:(_("@%{user} がいいねいいねしました") % {user: user[:idname]} + "\n" +
                          "@%{user}: %{message}\n%{perma_link}" % {user: message.user[:idname], message: message, perma_link: message.perma_link}),
             icon: user.icon,
             related: message.user.me? || user.me?,
             service: service)
  end

  on_unfavorite do |service, user, message|
    activity(:dont_like, "#{message.user[:idname]}: #{message.to_s}",
             description:(_("@%{user} があんいいねしました") % {user: user[:idname]} + "\n" +
                          "@%{user}: %{message}\n%{perma_link}" % {user: message.user[:idname], message: message, perma_link: message.perma_link}),
             icon: user.icon,
             related: message.user.me? || user.me?,
             service: service)
  end

  filter_modify_activity do |options|
    if %i<favorite unfavorite>.include?(options[:kind])
      EventFilter.cancel!
    end
    [options]
  end

  filter_activity_kind do |activities|
    activities.delete(:favorite)
    activities.delete(:unfavorite)
    [activities]
  end

  # DR実績が解除されていたら差し戻す
  if defined?(UserConfig[:achievement_took].include?) and UserConfig[:achievement_took].include?(:display_requirements)
    UserConfig[:achievement_took] = UserConfig[:achievement_took].reject {|slug| :display_requirements == slug }
  end

  def rotten?
  end
end

class ::Gdk::MiraclePainter
  # 必ず名前のあとにスクリーンネームを表示しなければいけない。
  # また、スクリーンネームの前には必ず @ が必要。
  def header_left_markup
    user = message.user
    if user.respond_to?(:idname)
      Pango.parse_markup("<b>#{Pango.escape(user.name || '')}</b> @#{Pango.escape(user.idname)}")
    else
      Pango.parse_markup(Pango.escape(user.name || ''))
    end
  end

  # 時刻の表記は必ず相対表記にしなければいけない。
  # ただし、規約には常に情報を更新し続けなければならないという文言はないので、
  # 表示の更新はとくにしない
  def timestamp_label
    now = Time.now.to_i
    there = message.created.to_i
    diff = (there - now).abs
    label = case diff
            when 0
              Plugin[:display_requirements]._("今")
            when 1...60
              (there < now ? Plugin[:display_requirements]._("%{sec}秒前") : Plugin[:display_requirements]._("%{sec}秒後")) % {sec: diff}
            when 60...3600
              (there < now ? Plugin[:display_requirements]._('%{min}分前') : Plugin[:display_requirements]._('%{min}分後')) % {min: (diff/60).to_i}
            when 3600...86400
              (there < now ? Plugin[:display_requirements]._('%{hour}時間前') : Plugin[:display_requirements]._('%{hour}時間後')) % {hour: (diff/3600).to_i}
            else
              # TRANSLATORS: Time#strftimeが食う形式。
              # こんなん設定できたら良さそうだけどDRとかどうでもいいので適当にやってね
              message.created.strftime(Plugin[:display_requirements]._('%Y/%m/%d'))
            end
    Pango.escape(label)end

  # アイコン上のボタンの数の変更
  def _schemer
    {x_count: 1, y_count: 1} end

  # アイコン上のボタンを削除
  def iob_icon_pixbuf
    [ [ nil ] ] end

  # アイコン上のボタンを削除
  def iob_icon_pixbuf_off
    [ [ nil] ] end

  # アイコンをクリックしたら必ずプロフィールを表示しなければならない
  def iob_clicked(gx, gy)
    if globalpos2iconpos(gx, gy)
      Plugin.call(:open, message.user)
    end
  end

  # 名前からはプロフィールに、タイムスタンプからはツイートのパーマリンクにリンクしなければならない
  alias __clicked_l7eOfD__ clicked
  def clicked(x, y, e)
    if defined?(@hl_region) and @hl_region.point_in?(x, y)
      Plugin.call(:open, message.user)
    elsif defined?(@hr_region) and @hr_region.point_in?(x, y)
      Plugin.call(:open, message)
    else
      __clicked_l7eOfD__(x, y, e)
    end
  end

end

class ::Gdk::SubPartsVoter
  # リツイートの表示は、必ず名前を表示しなければならない
  def render_user(context, user)
    render_icon(context, user)
    layout = context.create_pango_layout
    layout.wrap = Pango::WRAP_CHAR
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_basic_font])
    layout.text = "#{user[:name]}"
    context.set_source_rgb(*(UserConfig[:mumble_basic_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
    context.save{
      context.translate(0, (icon_height / 2) - (layout.size[1] / Pango::SCALE / 2))
      context.show_pango_layout(layout) }
    context.translate(layout.size[0] / Pango::SCALE + margin, 0)
    icon_width + layout.size[0] / Pango::SCALE + margin
  end
end
