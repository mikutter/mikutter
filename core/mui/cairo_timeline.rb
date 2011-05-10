require 'gtk2'

miquire :mui, 'crud'
miquire :mui, 'cell_renderer_message'
miquire :mui, 'timeline_utils'

class Gtk::TimeLine < Gtk::ScrolledWindow
  include Gtk::TimeLineUtils

  class InnerTL < Gtk::CRUD

    def self.current_tl
      @@current_tl end

    def initialize
      super
      @@current_tl ||= self
      set_headers_visible(false)
      signal_connect(:focus_in_event){
        @@current_tl = self
        false } end

    def cell_renderer_message
      @cell_renderer_message ||= Gtk::CellRendererMessage.new()
    end

    def column_schemer
      [ {:renderer => lambda{ |x,y|
            cell_renderer_message.tree = self
            # a.signal_connect(:click){|r, e, path, column, cell_x, cell_y|
            #   p [cell_x, cell_y, e.x, e.y]
            # }
            cell_renderer_message
          },
          :kind => :message_id, :widget => :text, :type => String, :label => ''},
        {:kind => :text, :widget => :text, :type => Message},
        {:kind => :text, :widget => :text, :type => Integer}
      ].freeze
    end

    def menu_pop(widget)
      menu = []
      Plugin.filtering(:contextmenu, []).first.each{ |x|
        cur = x.first
        cur = cur.call(nil, nil) if cur.respond_to?(:call)
        index = where_should_insert_it(cur, menu, UserConfig[:mumble_contextmenu_order] || [])
        menu[index] = x }
      if selection.selected
        Gtk::ContextMenu.new(*menu).popup(self, selection.selected[1]) end end

  end

  addlinkrule(URI.regexp(['http','https'])){ |url, widget|
    Gtk::TimeLine.openurl(url)
  }

  def self.get_active_mumbles
    selected = Set.new
    if InnerTL.current_tl
      InnerTL.current_tl.selection.selected_each{ |model, path, iter|
        selected << iter[1] }
    end
    selected
  end

  @@tls = WeakSet.new

  def initialize
    super
    @@tls << @tl = InnerTL.new
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
      @tl.cell_renderer_message.miracle_painter(message).signal_connect(:modified){ |mb|
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
