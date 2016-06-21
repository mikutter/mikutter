# -*- coding: utf-8 -*-

=begin rdoc
  Transifexと連携するためのユーティリティ
=end
module Transifex
  extend self

  SLUG_SIZE = 50
  CONTENT_TYPE_MULTIPART_FORMDATA = 'multipart/form-data'
  CONTENT_TYPE_APPLICATION_JSON = 'application/json'

  # Transifexプロジェクトの情報を取得する
  # ==== Args
  # [project_name] String プロジェクト名
  # ==== Return
  # Hashプロジェクトの情報
  def project_detail(project_name)
    get_request("http://www.transifex.com/api/2/project/#{project_name}/?details")
  end

  # resource(mikutterの場合はpotファイル)をアップロードし、新しいResourceとして登録する。
  # 既に同じslugを持つResourceは登録できない。代わりに、 Transifex.resource_update を使う
  # ==== Args
  # [project_name:] プロジェクト名
  # [slug:] String アップロードするresourceのslug。プラグインスラッグを使用する。50文字まで
  # [name:] String resourceの名前。プラグイン名を使用する。
  # [i18n_type:] String 翻訳形式。省略するとPO。mikutterでは必ず省略する。
  # [categories:] Array カテゴリ。いらん
  # [priority:] Transifex::Priority 翻訳優先順位。
  # [content:] IO|String resourceの内容。potファイルの中身のこと。IOを渡すとそれをreadした結果、Stringならその内容をそのままアップロードする
  # ==== Return
  # Hash レスポンス
  # ==== See
  # http://docs.transifex.com/api/resources/#uploading-and-downloading-resources
  # ==== Raise
  # SlugTooLongError slugが SLUG_SIZE 文字を超えている場合
  def resource_create(project_name:, slug:, name:, i18n_type: 'PO', categories: [], priority: Priority::NORMAL, content:)
    slug, name, priority = slug.to_s, name.to_s, priority.to_i
    raise SlugTooLongError, "The current maximum value for the field slug is #{SLUG_SIZE} characters. http://docs.transifex.com/api/resources/#uploading-and-downloading-resources" if slug.size > SLUG_SIZE
    if content.is_a? IO
      content = content.read end
    post_request("http://www.transifex.com/api/2/project/#{project_name}/resources/",
                 content_type: CONTENT_TYPE_APPLICATION_JSON,
                 params: {
                   slug: slug,
                   name: name,
                   i18n_type: i18n_type,
                   categories: categories,
                   priority: priority,
                   content: content
                 }
                )
  end

  # resource(mikutterの場合はpotファイル)をアップロードし、同じslugを持つResourceを上書きする。
  # 存在しないResourceは登録できない。代わりに、 Transifex.resource_create を使う
  # ==== Args
  # [project_name:] プロジェクト名
  # [slug:] String アップロードするresourceのslug。プラグインスラッグを使用する。50文字まで
  # [content:] IO|String resourceの内容。potファイルの中身のこと。IOを渡すとそれをreadした結果、Stringならその内容をそのままアップロードする
  # ==== Return
  # Hash レスポンス
  # ==== See
  # http://docs.transifex.com/api/resources/#uploading-and-downloading-translations-for-a-file
  def resource_update(project_name:, slug:, content:)
    slug = slug.to_s
    if content.is_a? IO
      content = content.read end
    put_request("http://www.transifex.com/api/2/project/#{project_name}/resource/#{slug}/content/",
                content_type: CONTENT_TYPE_APPLICATION_JSON,
                params: {content: content}
               )
  end

  def resource_get(project_name:, slug:)
    slug = slug.to_s
    get_request("http://www.transifex.com/api/2/project/#{project_name}/resource/#{slug}/content/")
  end

  private

  def get_request(url)
    clnt = HTTPClient.new
    clnt.set_auth(url, ENV['TRANSIFEX_USER'], ENV['TRANSIFEX_PASSWORD'])
    JSON.parse(clnt.get_content(url), symbolize_names: true)
  end

  def post_request(url, content_type: CONTENT_TYPE_MULTIPART_FORMDATA, params:)
    clnt = HTTPClient.new
    clnt.set_auth(url, ENV['TRANSIFEX_USER'], ENV['TRANSIFEX_PASSWORD'])
    case content_type
    when CONTENT_TYPE_MULTIPART_FORMDATA
      content = params
    when CONTENT_TYPE_APPLICATION_JSON
      content = params.to_json
    end
    JSON.parse(clnt.post_content(url, content, 'Content-Type' => content_type), symbolize_names: true)
  rescue HTTPClient::BadResponseError => err
    pp err.res.content
  end

  def put_request(url, content_type: CONTENT_TYPE_MULTIPART_FORMDATA, params:)
    clnt = HTTPClient.new
    clnt.set_auth(url, ENV['TRANSIFEX_USER'], ENV['TRANSIFEX_PASSWORD'])
    case content_type
    when CONTENT_TYPE_MULTIPART_FORMDATA
      content = params
    when CONTENT_TYPE_APPLICATION_JSON
      content = params.to_json
    end
    JSON.parse(clnt.__send__(:follow_redirect, :put, url, nil, content, 'Content-Type' => content_type).content, symbolize_names: true)
  rescue HTTPClient::BadResponseError => err
    pp err.res.content
  end


  class Priority
    attr_reader :to_i
    def initialize(prio)
      @to_i = prio.to_i end

    NORMAL = new(0)
    HIGH = new(1)
    URGENT = new(2)
  end

  class Error < RuntimeError; end
  class SlugTooLongError < Error; end
end
