# -*- coding: utf-8 -*-

module Plugin::Activity
  class Activity < Retriever::Model
    extend Memoist

    include Retriever::Model::MessageMixin
    include Retriever::Model::UserMixin

    register :activity, name: "Activity"

    field.string :description, required: true
    field.string :title, required: true
    field.string :icon
    field.bool :related
    field.string :plugin_slug
    field.time :date, required: true
    field.string :kind, required: true
    field.string :identity
    field.has :children, [Retriever::Model]
    # model_field
    # service

    # TLにアイコンを表示するため
    def profile_image_url
      icon || MUI::Skin.get_path('activity.png')
    end

    def plugin
      self[:plugin] || Plugin[plugin_slug]
    end

    def title
      self[:title].tr("\n", "")
    end

    def children
      self[:children] || []
    end

    # TLに表示するため
    def name
      title
    end

    # TLに表示するため
    def created
      date
    end

    def host
      kind.gsub('_', '-')
    end

    memoize def path
      if identity
        identity
      elsif children.empty?
        '/' + SecureRandom.uuid
      else
        children.inject('/'){|memo,child| memo + Digest::MD5.hexdigest(child.uri.to_s) + '/' }
      end
    end
  end
end
