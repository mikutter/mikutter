# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_voter'

require 'gtk2'
require 'cairo'

class Gdk::SubPartsRetweet < Gdk::SubPartsVoter
  regist

  def get_default_votes
    helper.message.retweeted_by
  end

  def label
    "RT" end

  def name
    :retweeted end

  Delayer.new{
    Plugin.create(:core).add_event(:retweet){ |retweets|
      retweets.deach{ |retweet|
        Gdk::MiraclePainter.findbymessage_d(retweet.retweet_source(true)).next{ |mps|
          mps.deach{ |mp|
            if not mp.destroyed? and mp.subparts
              begin
                mp.subparts.find{ |sp| sp.class == Gdk::SubPartsRetweet }.add(retweet[:user])
                mp.on_modify
              rescue Gtk::MiraclePainter::DestroyedError
                nil end end } }.terminate("retweet error") } } }

end
