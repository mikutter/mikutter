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
    Plugin.filter_cancel! if :search_hashtag == options[:filter_id]
    [options]
  end

  Message::Entity.addlinkrule(:hashtags, /(?:#|＃)[a-zA-Z0-9_]+/, :open_in_browser_hashtag){ |segment|
    Gtk.openurl("https://twitter.com/search/realtime?q="+CGI.escape(segment[:url].match(/^(?:#|＃)?.+$/)[0]))
  }
end

class ::Gdk::MiraclePainter
  # 必ず名前のあとにスクリーンネームを表示しなければいけない。
  # また、スクリーンネームの前には必ず @ が必要。
  def header_left_markup
    Pango.parse_markup("<b>#{Pango.escape(message[:user][:name] || '')}</b> @#{Pango.escape(message[:user][:idname])}")
  end

  # 時刻の表記は必ず相対表記にしなければいけない。
  # ただし、規約には常に情報を更新し続けなければならないという文言はないので、
  # 表示の更新はとくにしない
  def timestamp_label
    now = Time.now.to_i
    there = message[:created].to_i
    diff = (there - now).abs
    label = case diff
            when 0
              "今"
            when 1...60
              "#{diff}秒#{there < now ? '前' : "後"}"
            when 60...3600
              "#{(diff/60).to_i}分#{there < now ? '前' : "後"}"
            when 3600...86400
              "#{(diff/3600).to_i}時間#{there < now ? '前' : "後"}"
            else
              message[:created].strftime('%Y/%m/%d')
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
  def iob_clicked
    if(current_icon_pos)
      Plugin.call(:show_profile, Service.primary, message.user) end end

  # 名前からはプロフィールに、タイムスタンプからはツイートのパーマリンクにリンクしなければならない
  alias __clicked_l7eOfD__ clicked
  def clicked(x, y, e)
    if defined?(@hl_region) and @hl_region.point_in?(x, y)
      notice "#{@hl_region.rectangles.first.to_a} in #{x}, #{y}"
      Plugin.call(:show_profile, Service.primary, message.user)
    elsif defined?(@hr_region) and @hr_region.point_in?(x, y)
      Gtk.openurl("https://twitter.com/#{message.user.idname}/status/#{message.id}")
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


