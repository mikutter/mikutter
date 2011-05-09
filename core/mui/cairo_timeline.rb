require 'gtk2'

miquire :mui, 'crud'
miquire :mui, 'tweetrenderer'
miquire :mui, 'timeline_utils'

class Gtk::TimeLine < Gtk::ScrolledWindow
  include Gtk::TimeLineUtils

  class InnerTL < Gtk::CRUD

    def initialize
      super
      set_headers_visible(false)
    end

    def tweetrenderer
      @tweetrenderer ||= Gtk::TweetRenderer.new()
    end

    def column_schemer
      [ {:renderer => lambda{ |x,y|
            tweetrenderer.tree = self
            # a.signal_connect(:click){|r, e, path, column, cell_x, cell_y|
            #   p [cell_x, cell_y, e.x, e.y]
            # }
            tweetrenderer
          },
          :kind => :message_id, :widget => :text, :type => String, :label => ''},
        {:kind => :text, :widget => :text, :type => Message},
        {:kind => :text, :widget => :text, :type => Integer}
      ].freeze
    end
  end

  addlinkrule(URI.regexp(['http','https'])){ |url, widget|
    Gtk::TimeLine.openurl(url)
  }

  def initialize
    super
    @tl = InnerTL.new
    self.add_with_viewport(@tl)
    self.border_width = 0
    self.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_ALWAYS)
    @tl.model.set_sort_column_id(2, order = Gtk::SORT_DESCENDING)
  end

  def block_add(message)
    type_strict message => Message
    raise "id must than 1 but specified #{message[:id].inspect}" if message[:id] <= 0
    iter = @tl.model.append
    if(!any?{ |m| m[:id] == message[:id] })
      iter[0] = message[:id].to_s
      iter[1] = message
      iter[2] = message[:created].to_i
      @tl.tweetrenderer.miracle_painter(message).signal_connect(:modified){ |mb|
        iter[0] = iter[0]
        false
      }

    end
    self end

  def each(index=1)
    @tl.model.each{ |model,path,iter|
      yield(iter[index]) if iter[index].is_a?(Message)
    } end

  def clear
    @tl.model.clear
    self end

end
