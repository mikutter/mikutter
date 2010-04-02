miquire :mui, 'extension'

require 'gtk2'

class Gtk::Box
  def insert_child(child, index)
    front = self.children[0, index]
    front.each{|w|
      self.remove(w)
    }
    self.__send__(self.insert_func, child, false)
    front.reverse.each{|w|
      self.__send__(self.insert_func, w, false)
    }
  end
end

class Gtk::PriorityVBox < Gtk::VBox
  protected :pack_start, :pack_end, :reorder_child

  attr_accessor :insert_func

  def initialize(*args)
    super(*args)
    @priority = lambda{ |x| yield x }
    @insert_func = :pack_end
  end

  def pack(child, expand = true, fill = true, padding = 0)
    Gtk::Lock.synchronize do
      priority = @priority.call(child)
      if not((self.children.empty?) or (@priority.call(self.children.first) <=> priority) < 0) then
        catch(:exit) do
          self.children.each_with_index{|widget, index|
            if (@priority.call(widget) <=> priority) < 0 then
              self.insert_child(child, index)
              throw :exit
            end
          }
          self.insert_child(child, self.children.size)
        end
      else
        self.__send__(self.insert_func, child, expand, fill, padding)
      end
    end
  end

  def pack_all(children, expand = true, fill = true, padding = 0)
    children.sort_by{ |c| @priority.call(c) }.reverse_each{ |c|
      self.pack(c, expand, fill, padding)
    }
  end

end
