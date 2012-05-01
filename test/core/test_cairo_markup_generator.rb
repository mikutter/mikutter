# -*- coding: utf-8 -*-
require 'test/unit'
require 'mocha'
$cairo = true
require File.expand_path(File.dirname(__FILE__) + '/../helper')
# require File.expand_path(File.dirname(__FILE__) + '/../utils')
# require File.expand_path(File.dirname(__FILE__) + '/../lib/test_unit_extensions')
miquire :mui, 'markup_generator'
miquire :lib, 'test_unit_extensions'

$debug = true
# seterrorlevel(:notice)
$logfile = nil
$daemon = false
 # !> assigned but unused variable - type
class TC_MarkupGenerator < Test::Unit::TestCase

  def setup
    @klass = Class.new do
      attr_accessor :message
      include Gdk::MarkupGenerator

      def initialize(m = nil)
        @message = m end end end

  must "return message text" do
    text = "てすと"
    mg = @klass.new(mock())
    mg.message.expects(:to_show).returns(text) # !> shadowing outer local variable - points
    assert_equal("てすと", mg.main_text)
    text = "test"
    mg = @klass.new(mock())
    mg.message.expects(:to_show).returns(text)
    assert_equal("test", mg.main_text)
    text = 'test > http://google.com'
    mg = @klass.new(mock())
    mg.message.expects(:to_show).returns(text)
    assert_equal("test > http://google.com", mg.main_text)
  end # !> shadowing outer local variable - value

  must "return escaped message text" do # !> shadowing outer local variable - value
    text = "てすと"
    mg = @klass.new(mock()) # !> shadowing outer local variable - value
    mg.message.expects(:to_show).returns(text) # !> assigned but unused variable - micro
    assert_equal("てすと", mg.escaped_main_text)

    text = "test"
    mg = @klass.new(mock())
    mg.message.expects(:to_show).returns(text)
    assert_equal("test", mg.escaped_main_text)

    text = 'test > http://google.com'
    mg = @klass.new(mock())
    mg.message.expects(:to_show).returns(text)
    assert_equal("test &gt; http://google.com", mg.escaped_main_text)
  end

  must "return styled message text" do
    text = '@null > http://t.co/SP1shjLy {mktr'
    mg = @klass.new(mock())
    mg.message.stubs(:to_show => text,
                     :links => [{:slug=>:user_mentions, :range=>0...5, :face=>"@null", :from=>:_generate_value, :url=>"@null"},
                                {:slug=>:urls, :range=>8...28, :face=>"http://google.com", :from=>:_generate_value, :url=>"http://t.co/SP1shjLy"}])
    assert_equal('<span underline="single">@null</span> &gt; <span underline="single">http://google.com</span> {mktr', mg.styled_main_text)

    text = '12345 > http://t.co/SP1shjLy {mktr'
    mg = @klass.new(mock())
    mg.message.stubs(:to_show => text,
                     :links => [{:slug=>:urls, :range=>8...28, :face=>"http://google.com", :from=>:_generate_value, :url=>"http://t.co/SP1shjLy"}])
    assert_equal('12345 &gt; <span underline="single">http://google.com</span> {mktr', mg.styled_main_text)

  end

end
