# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_voter'

require 'gtk2'
require 'cairo'

class Gdk::SubPartsFavorite < Gdk::SubPartsVoter
  regist

  def get_default_votes
    helper.message.favorited_by
  end

  def title_icon
    Gdk::Pixbuf.new(Skin.get("unfav.png"), @icon_width, @icon_height) end

  def name
    :favorited end

  Delayer.new{
    Plugin.create(:core) do
      onfavorite do |service, user, message|
        Gdk::MiraclePainter.findbymessage_d(message).next{ |mps|
          mps.deach{ |mp|
            if not mp.destroyed?
              mp.subparts.find{ |sp| sp.class == Gdk::SubPartsFavorite }.add(user) end } }
      end

      on_before_favorite do |service, user, message|
        Gdk::MiraclePainter.findbymessage_d(message).next{ |mps|
          mps.deach{ |mp|
            if not mp.destroyed?
              mp.subparts.find{ |sp| sp.class == Gdk::SubPartsFavorite }.add(user) end } }
      end

      on_fail_favorite do |service, user, message|
        Gdk::MiraclePainter.findbymessage_d(message).next{ |mps|
          mps.deach{ |mp|
            if not mp.destroyed?
              mp.subparts.find{ |sp| sp.class == Gdk::SubPartsFavorite }.delete(user) end } }
      end
    end
  }

end
