# ruby
require 'gtk2'
miquire :mui, 'extension'
miquire :core, 'user'
miquire :mui, 'icon_over_button'

#
# TODO: timelineからコピペで作ったからリファクタリングしてモジュールを作る
#

module Gtk
  class UserList < Gtk::ScrolledWindow
    include Enumerable

    def initialize()
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
        @evbox, @ul = gen_userlist
        yield
        self.add_with_viewport(Gtk::VBox.new(false, 0).
                               pack_start(@evbox, false).
                               pack_start(Gtk::VBox.new)).show_all end end

    def each(&iter)
      userlist{
        @ul.children.each(&iter) } end

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
        elsif not all_id.include?(user[:id])
          user = Gtk::User.new(user).show_all
          @ul.pack_end(user, false) end end end

    #changed
    def block_add_all(users)
      Lock.synchronize do
        removes, appends = *users.partition{ |m| m[:rule] == :destroy }
        remove_if_exists_all(removes)
        appends.each(&method(:block_add))
#         if self.vadjustment.value != 0 then # changed
#           if self.should_return_top? then
#             self.vadjustment.value = 0
#           else
#             self.vadjustment.value += appends.size * 32
#           end
#         end
#         if(@ul.children.size > 200) then
#           (@ul.children.size - 200).times{ @ul.remove(@ul.children.last) }
#         end
      end
    end

    def remove_if_exists_all(users)
      if defined? @ul
        users.each{ |m|
          w = @ul.children.find{ |x| x[:id] == m[:id] }
          @ul.remove(w) if w } end
      self end

    def all_id
      if defined? @ul
        @ul.children.map{ |x| x[:id].to_i }
      else
        [] end end

    def clear
      if defined? @ul
        Lock.synchronize do
          @ul.children.each{ |elm|
            @ul.remove(elm) } end end
      self end

#     def should_return_top?
#       Gtk::PostBox.list.each{ |w|
#         return w.posting? if w.get_ancestor(Gtk::Userlist) == self and w.return_to_top }
#       false end

#     def has_mumbleinput?
#       Gtk::PostBox.list.each{ |w|
#         return true if w.get_ancestor(Gtk::Userlist) == self }
#       false end

    #changed
    def gen_userlist
      Lock.synchronize do
        container = Gtk::EventBox.new
        box = Gtk::VBox.new(false, 0)
        container.add(box)
        style = Gtk::Style.new()
        style.set_bg(Gtk::STATE_NORMAL, *[255,255,255].map{|a| a*255})
        container.style = style
        return container, box
      end
    end

#     def self.addlinkrule(reg, &proc)
#       Gtk::Mumble.addlinkrule(reg, proc) end

#     def self.addwidgetrule(reg, &proc)
#       Gtk::Mumble.addwidgetrule(reg, proc) end

  end

  class User < Gtk::EventBox
    attr_reader :user

    def initialize(user)
      super()
      @user = user
      add(Gtk::HBox.new(false, 0).
          closeup(Gtk::WebIcon.new(user[:profile_image_url], 24, 24)).
          add(Gtk::IntelligentTextview.new("@#{user[:idname]} #{user[:name]}")))
    end

    def [](key)
      @user[key] end

    def <=>(other)
      if defined?(other.to_a)
        to_a <=> other.to_a
      elsif other.is_a? Integer
        self[:id].to_i <=> other
      elsif other.is_a? Time
        self[:created] <=> other end end

  end

end
