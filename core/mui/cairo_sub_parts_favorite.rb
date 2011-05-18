# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_voter'

require 'gtk2'
require 'cairo'

class Gdk::SubPartsFavorite < Gdk::SubPartsVoter

  def get_default_votes
    helper.message.favorited_by
  end

  def label
    "fav" end

  def name
    :favorited end

  Delayer.new{
    Plugin.create(:core).add_event(:favorite){ |service, user, message|
      Gdk::MiraclePainter.findbymessage(message).each{ |mp|
        mp.subparts.find{ |sp| sp.class == Gdk::SubPartsFavorite }.add(user)
        mp.on_modify } } }

end
