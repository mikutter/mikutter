miquire :addon, 'addon'
miquire :mui, 'timeline'

module Addon
  class Worldcup < Addon

    HASHTAGS = ['#arg', '#aus', '#bra', '#chi', '#civ', '#cmr', '#den', '#eng', '#esp', '#fra',
                '#ger', '#gha', '#gre', '#hon', '#ita', '#jpn', '#kor', '#mex', '#ned', '#nga',
                '#nzl', '#par', '#por', '#prk', '#rsa', '#sui', '#usa', '#srb']

    include SettingUtils

    def onboot(watch)
      Gtk::TimeLine.addwidgetrule(/[#]([a-zA-Z0-9_]+)/){ |text|
        if(HASHTAGS.include?(text.downcase))
          Gtk::WebIcon.new('http://a1.twimg.com/a/1276197224/images/worldcup/24/'+
                           text[1, text.size].downcase+ '.png', 12, 12)
        elsif(['#worldcup'].include?(text.downcase))
          Gtk::WebIcon.new('http://twitter.com/images/worldcup/16/worldcup.png', 12, 12) end } end end
end

Plugin::Ring.push Addon::Worldcup.new,[:boot]
