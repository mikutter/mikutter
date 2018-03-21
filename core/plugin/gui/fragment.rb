# -*- coding: utf-8 -*-

require_relative 'cuscadable'
require_relative 'hierarchy_parent'
require_relative 'hierarchy_child'
require_relative 'window'
require_relative 'tablike'
require_relative 'widget'

class Plugin::GUI::Fragment
  extend Gem::Deprecate

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget
  include Plugin::GUI::TabLike

  role :fragment

  set_parent_event :gui_fragment_join_cluster

  attr_reader :model

  def initialize(*args)
    super
    Plugin.call(:fragment_created, self)
  end

  def retriever; model end
  def user; model end
  deprecate :retriever, "model", 2018, 03
  deprecate :user, "model", 2017, 2

  # 完全なユーザ情報が取得できたらコールバックする
  def model_complete(&callback)
    type_strict model => Diva::Model, callback => Proc
    if model[:exact]
      yield model
    else
      atomic {
        if not(defined?(@model_promise) and @model_promise)
          @model_promise = Service.primary.user_show(user_id: model[:id]).next{ |u|
            @model_promise = false
            u }.terminate{
            Plugin[:gui]._("%{user} のユーザ情報が取得できませんでした") % {user: model.title}
          } end
        @model_promise = @model_promise.next{ |u| callback.call(u); u } } end
  end
  alias :retriever_complete :model_complete
  deprecate :retriever_complete, "model_complete", 2018, 03

end
