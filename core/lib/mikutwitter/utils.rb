# -*- coding: utf-8 -*-

require "mikutwitter/basic"
require "lazy"
require "cgi"

module MikuTwitter::Utils

  attr_accessor :twitter_host, :base_path

  EXCLUDE_OPTIONS = [:cache].freeze

  def initialize(*a, &b)
    @twitter_host = 'api.twitter.com'
    @base_path = "http://#{@twitter_host}/1.1".freeze
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
      "?" + filtered.map{|pair| "#{CGI.escape(pair[0].to_s).to_s}=#{CGI.escape(pair[1].to_s).to_s}"}.join('&')
    else
      '' end end

  def line_accumlator(splitter="\n", &proc)
    splitter.freeze
    buffer = ""
    push = ->(str){ proc.(buffer + str); buffer = "" }
    ->(chunk){
      if chunk.end_with?(splitter)
        objects = chunk.split(splitter)
        if objects.empty? then push.("") else objects.each(&push) end
      else
        *objects, last = chunk.split(splitter)
        objects.each(&push)
        buffer += (last || "") end } end
end

class << CGI
  alias __escape_aoVit97__ escape
  def escape(*args)
    __escape_aoVit97__(*args).gsub(/[*:]/){|m| "%" + m.unpack("H2") }
  end
end

class MikuTwitter; include MikuTwitter::Utils end
