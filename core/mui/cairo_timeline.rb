require 'gtk2'

miquire :mui, 'crud'
miquire :mui, 'cell_renderer_message'
miquire :mui, 'timeline_utils'
miquire :mui, 'pseudo_message_widget'
miquire :mui, 'postbox'

class Gtk::TimeLine < Gtk::VBox #Gtk::ScrolledWindow
  include Gtk::TimeLineUtils

  class InnerTL < Gtk::CRUD

    attr_accessor :postbox

    def self.current_tl
      @@current_tl end

    def initialize
      super
      @@current_tl ||= self
      set_headers_visible(false)
      # get_column(0).resizable = true
      # get_column(0).sizing = (Gtk::TreeViewColumn::FIXED)
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

    def menu_pop(widget, event)
      menu = []
      Plugin.filtering(:contextmenu, []).first.each{ |x|
        cur = x.first
        cur = cur.call(nil, nil) if cur.respond_to?(:call)
        index = where_should_insert_it(cur, menu, UserConfig[:mumble_contextmenu_order] || [])
        menu[index] = x }
      if selection.selected
        Gtk::ContextMenu.new(*menu).popup(self, Gtk::PseudoMessageWidget.new(selection.selected, event, self)) end end

    def handle_row_activated
    end

    def reply(message, options = {})
      message = model.get_iter(message) if(message.is_a?(Gtk::TreePath))
      message = message[1] if(message.is_a?(Gtk::TreeIter))
      type_strict message => Message
      postbox.closeup(pb = Gtk::PostBox.new(message, options).show_all)
      get_ancestor(Gtk::Window).set_focus(pb.post)
      self end

  end

  addlinkrule(URI.regexp(['http','https'])){ |url, widget|
    Gtk::TimeLine.openurl(url)
  }

  def self.get_active_mumbles
    selected = Set.new
    if InnerTL.current_tl
      InnerTL.current_tl.selection.selected_each{ |model, path, iter|
        selected << iter[1] } end
    selected end

  @@tls = WeakSet.new

  def initialize
    super
    @@tls << @tl = InnerTL.new
    @tl.postbox = postbox
    scrollbar = Gtk::VScrollbar.new(@tl.vadjustment)
    closeup(postbox).pack_start(Gtk::HBox.new.pack_start(@tl).closeup(scrollbar))
    @tl.model.set_sort_column_id(2, order = Gtk::SORT_DESCENDING)
    @tl.set_size_request(100, 100)
    @tl.get_column(0).sizing = Gtk::TreeViewColumn::FIXED
    scroll_to_top_anime = false
    @tl.vadjustment.signal_connect(:value_changed){ |this|
      if(scroll_to_zero? and not(scroll_to_top_anime))
        scroll_to_top_anime = true
        scroll_speed = 4
        Gtk.timeout_add(25){
          @tl.vadjustment.value -= (scroll_speed *= 2)
          scroll_to_top_anime = @tl.vadjustment.value > 0.0
        }
      end
      false
    }
  end

  def block_add(message)
    type_strict message => Message
    raise "id must than 1 but specified #{message[:id].inspect}" if message[:id] <= 0
    iter = @tl.model.append
    if(!any?{ |m| m[:id] == message[:id] })
      scroll_to_zero_lator! if @tl.vadjustment.value == 0.0
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

  private

  def postbox
    @postbox ||= Gtk::VBox.new end

  def scroll_to_zero_lator!
    @scroll_to_zero_lator = true end

  def scroll_to_zero?
    result = (defined?(@scroll_to_zero_lator) and @scroll_to_zero_lator)
    @scroll_to_zero_lator = false
    result end

end
