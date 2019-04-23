module Plugin::Worldon
  class AttachmentMeta < Diva::Model
    #register :worldon_attachment_meta, name: "Mastodon添付メディア メタ情報(Worldon)"

    field.int :width
    field.int :height
    field.string :size
    field.string :aspect
  end

  class AttachmentMetaSet < Diva::Model
    #register :worldon_attachment_meta, name: "Mastodon添付メディア メタ情報セット(Worldon)"

    field.has :original, AttachmentMeta
    field.has :small, AttachmentMeta
  end

  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#attachment
  class Attachment < Diva::Model
    #register :worldon_attachment, name: "Mastodon添付メディア(Worldon)"

    field.string :id, required: true
    field.string :type, required: true
    field.uri :url
    field.uri :remote_url
    field.uri :preview_url, required: true
    field.uri :text_url
    field.string :description

    field.has :meta, AttachmentMetaSet

    def inspect
      "worldon-attachment(#{remote_url})"
    end
  end
end
