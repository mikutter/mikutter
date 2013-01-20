# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_voter'

require 'gtk2'
require 'cairo'

class Gdk::SubPartsRetweet < Gdk::SubPartsVoter
  regist

  def get_default_votes
    helper.message.retweeted_by
  end

  def title_icon
    Gdk::Pixbuf.new(Skin.get("retweet.png"), @icon_width, @icon_height) end

  def name
    :retweeted end

  Plugin.create(:core) do
    on_retweet do |retweets|
      retweets.deach{ |retweet|
        Gdk::MiraclePainter.findbymessage_d(retweet.retweet_source(true)).next{ |mps|
          mps.deach{ |mp|
            if not mp.destroyed? and mp.subparts
              begin
                mp.subparts.find{ |sp| sp.class == Gdk::SubPartsRetweet }.add(retweet[:user])
                mp.on_modify
              rescue Gtk::MiraclePainter::DestroyedError
                nil end end } }.terminate("retweet error") } end

    on_retweet_destroyed do |source, user, retweet_id|
      Gdk::MiraclePainter.findbymessage_d(source).next{ |mps|
        mps.deach{ |mp|
            if not mp.destroyed? and mp.subparts
              begin
                mp.subparts.find{ |sp| sp.class == Gdk::SubPartsRetweet }.delete(user)
                mp.on_modify
              rescue Gtk::MiraclePainter::DestroyedError
                nil end end }.terminate("retweet destroy error")
      }
    end
  end

end


