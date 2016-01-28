# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_parent')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'window')
require File.expand_path File.join(File.dirname(__FILE__), 'tablike')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::Fragment
  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget
  include Plugin::GUI::TabLike

  role :fragment

  set_parent_event :gui_profiletab_join_profile

  attr_reader :user
  attr_accessor :profile_slug

  def initialize(*args)
    super
    Plugin.call(:profiletab_created, self)
  end

  # 完全なユーザ情報が取得できたらコールバックする
  def user_complete(&callback)
    type_strict user => User, callback => Proc
    if user[:exact]
      yield user
    else
      atomic {
        if not(defined?(@user_promise) and @user_promise)
          @user_promise = Service.primary.user_show(user_id: user[:id]).next{ |u|
            @user_promise = false
            u }.terminate{
            Plugin[:gui]._("%{user} のユーザ情報が取得できませんでした") % {user: user[:idname]}
          } end
        @user_promise = @user_promise.next{ |u| callback.call(u); u } } end
  end

end
