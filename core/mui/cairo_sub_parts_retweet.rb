# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_voter'

require 'gtk2'
require 'cairo'

class Gdk::SubPartsRetweet < Gdk::SubPartsVoter

  def get_default_votes
    helper.message.retweeted_by
  end

  def label
    "RT" end

  def name
    :retweet end

  Delayer.new{
    Plugin.create(:core).add_event(:retweet){ |retweets|
      SerialThread.new{
        retweets.each{ |retweet|
          Gdk::MiraclePainter.findbymessage(retweet.retweet_source(true)).each{ |mp|
            mp.subparts.find{ |sp| sp.class == Gdk::SubPartsRetweet }.add(retweet[:user])
            mp.on_modify } } } } }

end
