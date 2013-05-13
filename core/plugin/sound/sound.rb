# # -*- coding: utf-8 -*-

Plugin.create :sound do
  Sound = Struct.new(:slug, :name, :play)

  # サウンドDSL
  defdsl :defsound do |slug, name, &play|
    filter_sound_servers do |servers|
      [servers + [Sound.new(slug, name, play)]] end end

  on_play_sound do |filename|
    use_sound_server = UserConfig[:sound_server]
    Plugin.filtering(:sound_servers, []).first.each{ |value|
      if not(use_sound_server) or use_sound_server == value.slug
        value.play.call(filename)
        break end } end

  settings "サウンド" do
    select "サウンドの再生方法", :sound_server do
      Plugin.filtering(:sound_servers, []).first.each{ |value|
        option value.slug, value.name } end end

end
