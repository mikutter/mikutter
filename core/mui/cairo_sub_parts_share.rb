# -*- coding: utf-8 -*-

require 'mui/cairo_sub_parts_voter'

require 'gtk2'
require 'cairo'

class Gdk::SubPartsShare < Gdk::SubPartsVoter
  extend Memoist

  register

  def get_vote_count
    [helper.message[:retweet_count] || 0, super].max
  end

  def get_default_votes
    helper.message.retweeted_by || []
  end

  memoize def title_icon_model
    Skin[:retweet]
  end

  def name
    :shared end

  Delayer.new do
    Plugin.create(:sub_parts_share) do
      share = ->(user, message) {
        Gdk::MiraclePainter.findbymessage_d(message).next { |mps|
          mps.reject(&:destroyed?).each do |mp|
            mp.subparts.find { |sp| sp.class == Gdk::SubPartsShare }.add(user)
          end
        }.terminate
      }

      on_share(&share)
      on_before_share(&share)

      destroy_share = ->(user, message) do
        Gdk::MiraclePainter.findbymessage_d(message).next { |mps|
          mps.reject(&:destroyed?).each do |mp|
            mp.subparts.find { |sp| sp.class == Gdk::SubPartsShare }.delete(user)
          end
        }.terminate
      end

      on_fail_share(&destroy_share)
      on_destroy_share(&destroy_share)
    end
  end

end
