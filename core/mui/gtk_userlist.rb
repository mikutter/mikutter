# ruby
require 'gtk2'
miquire :mui, 'extension'
miquire :core, 'user'
miquire :mui, 'icon_over_button'

require 'set'

#
# TODO: timelineからコピペで作ったからリファクタリングしてモジュールを作る
#

module Gtk
  class UserList < Gtk::ScrolledWindow
    include Enumerable

    attr_accessor :double_clicked

    def initialize()
      @users = Set.new
      @double_clicked = ret_nth
      @block_add = method(:block_add).to_proc
      super()
      Lock.synchronize do
        self.border_width = 0
        self.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_ALWAYS)
      end
    end

    def userlist
      if defined? @ul
        yield
      else
        @evbox, @ul, @treeview = gen_userlist
        yield
        self.add_with_viewport(Gtk::VBox.new(false, 0).
                               pack_start(@evbox, false).
                               pack_start(Gtk::VBox.new)).show_all end end

    def each(&iter)
      @users.each(&iter)
    end

    def add(user)
      userlist{
        if user.is_a?(Array) then
          self.block_add_all(user)
        else
          self.block_add(user) end }
      self.show_all end

    def block_add(user)
      Lock.synchronize do
        if user[:rule] == :destroy
          remove_if_exists_all([user])
        elsif not @users.include?(user)
          iter = @ul.prepend
          iter[0] = Gtk::WebIcon.get_icon_pixbuf(user[:profile_image_url], 24, 24){ |pixbuf|
            iter[0] = pixbuf }
          iter[1] = user[:idname]
          iter[2] = user[:name]
          iter[3] = user
          @users << user end end end

    def block_add_all(users)
      Lock.synchronize do
        removes, appends = *users.partition{ |m| m[:rule] == :destroy }
        remove_if_exists_all(removes)
        appends.each(&@block_add)
      end
    end

    def remove_if_exists_all(users)
      if defined? @ul
        Lock.synchronize do
          users_idname = users.map{ |user| user[:idname] }.freeze
          @ul.each{ |model, path, iter|
            remove_user_name = iter[1].to_s
            if users_idname.include?(remove_user_name)
              @ul.remove(iter)
              @users.delete_if{ |user| user[:idname] == remove_user_name }
            end }
          end end
      self end

    def all_id
      if defined? @ul
        @users.map{ |x| x[:id].to_i }
      else
        [] end end

    def clear
      if defined? @treeview
        Lock.synchronize do
          @treeview.clear
          @users.clear end end
      self end

    def gen_userlist
      Lock.synchronize do
        container = Gtk::EventBox.new
        box = Gtk::ListStore.new(Gdk::Pixbuf, String, String, User)
        treeview = Gtk::TreeView.new(box)
        crText = Gtk::CellRendererText.new
        col = Gtk::TreeViewColumn.new 'icon', Gtk::CellRendererPixbuf.new, :pixbuf => 0
        col.resizable = true
        treeview.append_column col

        col = Gtk::TreeViewColumn.new 'ユーザID', Gtk::CellRendererText.new, :text => 1
        col.resizable = true
        treeview.append_column col

        col = Gtk::TreeViewColumn.new '名前', Gtk::CellRendererText.new, :text => 2
        col.resizable = true
        treeview.append_column col

        treeview.set_enable_search(true).set_search_column(1).set_search_equal_func{ |model, columnm, key, iter|
          not iter[columnm].include?(key) }

        treeview.signal_connect("row-activated") do |view, path, column|
          puts "Row #{path.to_str} was clicked!"
          if iter = view.model.get_iter(path)
            puts "Double-clicked row contains name #{iter[1]}!"
            double_clicked.call(iter[3])
          end
        end

        container.add(treeview)
        style = Gtk::Style.new()
        style.set_bg(Gtk::STATE_NORMAL, *[255,255,255].map{|a| a*255})
        container.style = style
        return container, box, treeview
      end
    end

    #     def self.addlinkrule(reg, &proc)
    #       Gtk::Mumble.addlinkrule(reg, proc) end

    #     def self.addwidgetrule(reg, &proc)
    #       Gtk::Mumble.addwidgetrule(reg, proc) end

  end

#   class UserList < Gtk::ScrolledWindow
#     include Enumerable

#     def initialize()
#       super()
#       Lock.synchronize do
#         self.border_width = 0
#         self.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_ALWAYS)
#       end
#     end

#     def userlist
#       if defined? @ul
#         yield
#       else
#         @evbox, @ul = gen_userlist
#         yield
#         self.add_with_viewport(Gtk::VBox.new(false, 0).
#                                pack_start(@evbox, false).
#                                pack_start(Gtk::VBox.new)).show_all end end

#     def each(&iter)
#       userlist{
#         @ul.children.each(&iter) } end

#     def add(user)
#       userlist{
#         if user.is_a?(Array) then
#           self.block_add_all(user)
#         else
#           self.block_add(user) end }
#       self.show_all end

#     def block_add(user)
#       Lock.synchronize do
#         if user[:rule] == :destroy
#           remove_if_exists_all([user])
#         elsif not all_id.include?(user[:id])
#           user = Gtk::User.new(user).show_all
#           @ul.pack_end(user, false) end end end

#     #changed
#     def block_add_all(users)
#       Lock.synchronize do
#         removes, appends = *users.partition{ |m| m[:rule] == :destroy }
#         remove_if_exists_all(removes)
#         appends.each(&method(:block_add))
#         #         if self.vadjustment.value != 0 then # changed
#         #           if self.should_return_top? then
#         #             self.vadjustment.value = 0
#         #           else
#         #             self.vadjustment.value += appends.size * 32
#         #           end
#         #         end
#         #         if(@ul.children.size > 200) then
#         #           (@ul.children.size - 200).times{ @ul.remove(@ul.children.last) }
#         #         end
#       end
#     end

#     def remove_if_exists_all(users)
#       if defined? @ul
#         users.each{ |m|
#           w = @ul.children.find{ |x| x[:id] == m[:id] }
#           @ul.remove(w) if w } end
#       self end

#     def all_id
#       if defined? @ul
#         @ul.children.map{ |x| x[:id].to_i }
#       else
#         [] end end

#     def clear
#       if defined? @ul
#         Lock.synchronize do
#           @ul.children.each{ |elm|
#             @ul.remove(elm) } end end
#       self end

#     #     def should_return_top?
#     #       Gtk::PostBox.list.each{ |w|
#     #         return w.posting? if w.get_ancestor(Gtk::Userlist) == self and w.return_to_top }
#     #       false end

#     #     def has_mumbleinput?
#     #       Gtk::PostBox.list.each{ |w|
#     #         return true if w.get_ancestor(Gtk::Userlist) == self }
#     #       false end

#     #changed
#     def gen_userlist
#       Lock.synchronize do
#         container = Gtk::EventBox.new
#         box = Gtk::VBox.new(false, 0)
#         container.add(box)
#         style = Gtk::Style.new()
#         style.set_bg(Gtk::STATE_NORMAL, *[255,255,255].map{|a| a*255})
#         container.style = style
#         return container, box
#       end
#     end

#     #     def self.addlinkrule(reg, &proc)
#     #       Gtk::Mumble.addlinkrule(reg, proc) end

#     #     def self.addwidgetrule(reg, &proc)
#     #       Gtk::Mumble.addwidgetrule(reg, proc) end

#   end

#   class User < Gtk::EventBox
#     attr_reader :user

#     def initialize(user)
#       super()
#       @user = user
#       add(Gtk::HBox.new(false, 0).
#           closeup(Gtk::WebIcon.new(user[:profile_image_url], 24, 24)).
#           add(Gtk::IntelligentTextview.new("@#{user[:idname]} #{user[:name]}")))
#     end

#     def [](key)
#       @user[key] end

#     def <=>(other)
#       if defined?(other.to_a)
#         to_a <=> other.to_a
#       elsif other.is_a? Integer
#         self[:id].to_i <=> other
#       elsif other.is_a? Time
#         self[:created] <=> other end end

#   end

end
# ~> -:3: undefined method `miquire' for main:Object (NoMethodError)
