# -*- coding: utf-8 -*-
#! /usr/bin/ruby

require File.expand_path('utils')
miquire :core,'environment'
miquire :core,'configloader'

require_if_exist 'rubygems'
require_if_exist 'stemmer'
require_if_exist 'classifier'

class AutoTag

  include ConfigLoader

  def initialize
    @rule = at(:rule)
    if not(Environment::AutoTag) then
      notice "AutoTag disabled by config"
    elsif defined?(Classifier) then
      warn 'gem, stemmer or classifier not found! AutoTag disabled'
    elsif not(command_exist?('mecab')) then
      warn('mecab not found! AutoTag disabled')
    else
      notice('AutoTag enabled')
      return
    end
    class << self
      def get(src)
        self.hashtags(src)
      end
    end
  end

  def get(src)
    tags = hashtags(src)
    if(!tags.empty?)
      return regist(tags, src)
    else
      if(@rule) then
        return [@rule.classify(src.to_wakati).downcase.gsub(" ", "_")]
      end
      return nil
    end
  end

  def hashtags(post)
    post.split(' ').select{ |token| token =~ /^#[a-zA-Z0-9_]+$/ }
  end

  def regist(tags, src)
    tag = tags.join('-')
    if(tag) then
      if(@rule)then
        @rule.add_category(tag)
      else
        @rule = Classifier::Bayes.new(tag)
      end
      @rule.train(tag, src.to_wakati)
      store(:rule, @rule) if $learnable
    end
    return tags
  end
end

if __FILE__ == $0 then
  atag = AutoTag.new
  p atag.get(gets.chomp)
end
