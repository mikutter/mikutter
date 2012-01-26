# -*- coding: utf-8 -*-

require "mikutwitter/basic"
require "lazy"

module MikuTwitter::Utils

  attr_accessor :twitter_host, :base_path

  EXCLUDE_OPTIONS = [:cache].freeze

  def initialize(*a, &b)
    @twitter_host = 'api.twitter.com'
    @base_path = "http://#{@twitter_host}/1".freeze
    super(*a, &b)
  end

  # 連想配列を受け取って、QueryStringを生成して返す
  # ==== Args
  # [args] QueryStringのHash
  # ==== Return
  # URLの?以降のクエリ文字列（"?"含む）。無い場合は空の文字列
  def get_args(args)
    filtered = lazy{ args.select{|k, v| not EXCLUDE_OPTIONS.include? k } }
    if not(args.empty? or filtered.empty?)
      "?" + filtered.map{|pair| "#{URI.encode_www_form_component(pair[0].to_s).to_s}=#{URI.encode_www_form_component(pair[1].to_s).to_s}"}.join('&')
    else
      '' end end
 # !> loading in progress, circular require considered harmful - /home/toshi/Documents/hobby/scripts/mikutter/trunk/core/lib/oauth/client/helper.rb
end

class MikuTwitter; include MikuTwitter::Utils end
