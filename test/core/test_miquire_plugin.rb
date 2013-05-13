# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha'
require File.expand_path(File.dirname(__FILE__)+'/../helper')

miquire :core, "miquire_plugin"

Miquire::Plugin.loadpath << File.join(File.dirname(__FILE__), "miquire/plugin")

class TC_MiquirePlugin < Test::Unit::TestCase
  def setup
    Plugin.clear!
  end

  must "to_hash return all spec" do
    hash = Miquire::Plugin.to_hash
    assert_equal :standalone, hash[:standalone][:slug]
  end

  must "get plugin slug by path (spec exist)" do
    assert_equal(:standalone, Miquire::Plugin.get_slug(File.expand_path(File.join(File.dirname(__FILE__), 'miquire/standalone'))))
    assert_equal(:parent_not_found, Miquire::Plugin.get_slug(File.expand_path(File.join(File.dirname(__FILE__), 'miquire/parent_not_found'))))
    assert_equal(:tooold, Miquire::Plugin.get_slug(File.expand_path(File.join(File.dirname(__FILE__), 'miquire/tooold'))))
  end

  must "get plugin slug by plugin path" do
    assert_equal(:standalone, Miquire::Plugin.get_slug(File.expand_path(File.join(File.dirname(__FILE__), 'miquire/standalone'))),
                 "spec がないとき slug が取得できる")
    assert_equal(:not_exist, Miquire::Plugin.get_slug(File.expand_path(File.join(File.dirname(__FILE__), 'miquire/not_exist'))),
                 "plugin が存在しないとき slug が取得できる")
    assert_equal(:display_requirements, Miquire::Plugin.get_slug(File.expand_path(File.join(File.dirname(__FILE__), 'miquire/display_requirements.rb'))),
                 "plugin が一つの.rbファイルだけの時 slug が取得できる")
  end

  must "get spec by plugin path" do
    standalone = Miquire::Plugin.get_spec(File.expand_path(File.join(File.dirname(__FILE__), 'miquire/plugin/standalone')))
    not_exist = Miquire::Plugin.get_spec(File.expand_path(File.join(File.dirname(__FILE__), 'miquire/plugin/not_exist')))
    display_requirements = Miquire::Plugin.get_spec(File.expand_path(File.join(File.dirname(__FILE__), 'miquire/plugin/display_requirements.rb')))

    assert_kind_of(Hash, standalone,
                   "spec file がないとき plugin があれば spec を取得できる")
    assert_equal(:standalone, standalone[:slug],
                 "spec file がないとき plugin があれば spec を取得できる")
    assert_nil(not_exist,
               "plugin がないときは slug を取得できない")
    assert_kind_of(Hash, display_requirements,
                   "plugin ファイルが単一の時、 spec を取得できる")
    assert_equal(:display_requirements, display_requirements[:slug],
                 "plugin ファイルが単一の時、 spec を取得できる")
  end

  must "get spec by plugin slug" do
    standalone = Miquire::Plugin.get_spec_by_slug(:standalone)
    not_exist = Miquire::Plugin.get_spec_by_slug(:not_exist)
    display_requirements = Miquire::Plugin.get_spec_by_slug(:display_requirements)

    assert_kind_of(Hash, standalone,
                   "spec file がないとき plugin があれば spec を取得できる")
    assert_equal(:standalone, standalone[:slug],
                 "spec file がないとき plugin があれば spec を取得できる")
    assert_nil(not_exist,
               "plugin がないときは slug を取得できない")
    assert_kind_of(Hash, display_requirements,
                   "plugin ファイルが単一の時、 spec を取得できる")
    assert_equal(:display_requirements, display_requirements[:slug],
                 "plugin ファイルが単一の時、 spec を取得できる")
  end

  must "load plugin by symbol" do
    assert(Miquire::Plugin.load(:standalone),
           "プラグインがロードできる")
    assert(Plugin.instance_exist?(:standalone), "プラグインがロードできる")
    assert_equal(false, Miquire::Plugin.load(:not_exist), "存在しないプラグインはロードできない")
  end

  must "load plugin by slug" do
    assert(Miquire::Plugin.load(Miquire::Plugin.get_spec_by_slug(:standalone)),
           "プラグインがロードできる")
    assert(Plugin.instance_exist?(:standalone), "プラグインがロードできる")
    assert_raise(ArgumentError, "存在しないプラグインはロードできない") {
      Miquire::Plugin.load(Miquire::Plugin.get_spec_by_slug(:not_exist))
    }
  end

  must "load child plugin with parent" do
    assert(Miquire::Plugin.load(:child),
           "依存関係のあるプラグインをロードできる")
    assert(Plugin.instance_exist?(:child), "依存のあるプラグインをロードできる")
    assert(Plugin.instance_exist?(:parent), "依存されているプラグインも自動でロードされる")
  end

  must "load error depended plugin not exists." do
    assert_raise(Miquire::LoadError, "依存しているプラグインがない場合ロードに失敗する") {
      Miquire::Plugin.load(:parent_not_found)
    }
    assert(!Plugin.instance_exist?(:parent_not_found), "依存しているプラグインがない場合ロードに失敗する")
  end

end
