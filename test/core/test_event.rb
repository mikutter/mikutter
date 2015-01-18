# -*- coding: utf-8 -*-

require File.expand_path(File.dirname(__FILE__) + '/../helper')

Dir.chdir(File.expand_path(File.dirname(__FILE__) + '/../core'))
$LOAD_PATH.push '.'
require 'utils'

miquire :lib, 'test_unit_extensions'
miquire :core, 'event', 'event_listener', 'event_filter'

class TC_Event < Test::Unit::TestCase
  def setup
    Event.clear!
  end

  def wait
    while !Delayer.empty?
      Delayer.run
    end
  end

  must "register" do
    assert_instance_of Event, Event[:register_test]
    assert Event[:register_test].eql? Event[:register_test]
    assert_raise(ArgumentError) {
      Event["fail"] }
  end

  must "priority" do
    assert_kind_of Symbol, Event[:prio1].priority
    Event[:prio1].options[:priority] = :ui_response
    assert_equal :ui_response, Event[:prio1].priority
  end

  must "call event with filtering" do
    r = 0
    EventListener.new(Event[:call_event]) do |v|
      r = v end
    Event[:call_event].call(1)
    wait
    assert_equal 1, r, 'イベントを呼び出すことができる'
    r = 0
    EventFilter.new(Event[:call_event]) do |v|
      [v + 1] end
    Event[:call_event].call(1)
    wait
    assert_equal 2, r, 'フィルタがあるイベントを呼び出すことができる'
  end

  must "call event with filtering in another thread" do
    Event.filter_another_thread = true
    r = 0
    EventListener.new(Event[:call_event]) do |v|
      r = v end
    Event[:call_event].call(1)
    Delayer.run while not Delayer.empty?
    assert_equal 1, r, 'フィルタを別スレッドで実行する設定の時、フィルタのないイベントを呼び出すことができる'
    r = 0
    EventFilter.new(Event[:call_event]) do |v|
      [v + 1] end
    Event[:call_event].call(1)
    wait
    assert_equal 2, r, 'フィルタがバックグラウンドスレッドで実行される'
  end

  must "called event raises exception" do
    r = 0
    EventListener.new(Event[:call_event]) do |v|
      r = v
      raise end
    Event[:call_event].call(1)
    assert_raise('イベント中で例外が起こった時、Delayer#runがその例外を投げる') {
      wait }
    assert_equal(1, r)
    r = 0
    EventFilter.new(Event[:call_event]) do |v|
      [v + 1] end
    Event[:call_event].call(1)
    assert_raise('フィルタがあるイベント中で例外が起こった時、Delayer#runがその例外を投げる') {
      wait }
    assert_equal(2, r)
    r = 0
    EventFilter.new(Event[:call_event]) do |v|
      raise
      [v] end
    Event[:call_event].call(1)
    assert_raise('フィルタで例外が起こった場合、EventListenerは実行されず、Delayer#runがその例外を投げる') {
      wait }
    assert_equal(0, r)

  end

  must "call event with filter raises exception in another thread" do
    Event.filter_another_thread = true
    r = 0
    exception = Class.new(RuntimeError)
    EventListener.new(Event[:call_event]) do |v|
      r = v
      raise exception end
    Event[:call_event].call(1)
    assert_raise(exception, 'イベント中で例外が起こった時、Delayer#runがその例外を投げる') {
      wait }
    assert_equal(1, r)
    r = 0
    EventFilter.new(Event[:call_event]) do |v|
      [v + 1] end
    Event[:call_event].call(1)
    assert_raise(exception, 'フィルタがあるイベント中で例外が起こった時、Delayer#runがその例外を投げる') {
      wait }
    assert_equal(2, r)
    r = 0
    filter_exception = Class.new(RuntimeError)
    EventFilter.new(Event[:call_event]) do |v|
      raise filter_exception
      [v] end
    Event[:call_event].call(1)
    assert_raise(filter_exception, 'フィルタで例外が起こった場合、EventListenerは実行されず、Delayer#runがその例外を投げる') {
      wait }
    assert_equal(0, r)
  end
end
