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
        retweets.each{ |retweet|
        Delayer.new{
          Gdk::MiraclePainter.findbymessage(retweet.retweet_source(true)).each{ |mp|
            if not mp.destroyed?
              begin
                mp.subparts.find{ |sp| sp.class == Gdk::SubPartsRetweet }.add(retweet[:user])
                mp.on_modify
              rescue Gtk::MiraclePainter::DestroyedError
                nil end end } } } } }

end
