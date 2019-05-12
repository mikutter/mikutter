module Plugin::Mastodon
  class AttachmentMeta < Diva::Model
    #register :mastodon_attachment_meta, name: "Mastodon添付メディア メタ情報(Mastodon)"

    field.int :width
    field.int :height
    field.string :size
    field.string :aspect
  end

  class AttachmentMetaSet < Diva::Model
    #register :mastodon_attachment_meta, name: "Mastodon添付メディア メタ情報セット(Mastodon)"

    field.has :original, AttachmentMeta
    field.has :small, AttachmentMeta
  end

  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#attachment
  class Attachment < Diva::Model
    #register :mastodon_attachment, name: "Mastodon添付メディア(Mastodon)"

    field.string :id, required: true
    field.string :type, required: true
    field.uri :url
    field.uri :remote_url
    field.uri :preview_url, required: true
    field.uri :text_url
    field.string :description

    field.has :meta, AttachmentMetaSet

    def inspect
      "mastodon-attachment(#{remote_url})"
    end
  end
end
