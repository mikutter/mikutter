# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_parent')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'window')
require File.expand_path File.join(File.dirname(__FILE__), 'tablike')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::Fragment
  extend Gem::Deprecate

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget
  include Plugin::GUI::TabLike

  role :fragment

  set_parent_event :gui_fragment_join_cluster

  attr_reader :retriever
  attr_accessor :profile_slug

  def initialize(*args)
    super
    Plugin.call(:fragment_created, self)
  end

  alias :user :retriever
  deprecate :user, "retriever", 2017, 2

  # 完全なユーザ情報が取得できたらコールバックする
  def retriever_complete(&callback)
    type_strict retriever => Retriever::Model, callback => Proc
    if retriever[:exact]
      yield retriever
    else
      atomic {
        if not(defined?(@retriever_promise) and @retriever_promise)
          @retriever_promise = Service.primary.user_show(user_id: retriever[:id]).next{ |u|
            @retriever_promise = false
            u }.terminate{
            Plugin[:gui]._("%{user} のユーザ情報が取得できませんでした") % {user: retriever[:idname]}
          } end
        @retriever_promise = @retriever_promise.next{ |u| callback.call(u); u } } end
  end

end
