module Diva::Entity
  AnchorLinkEntity = RegexpEntity.filter(/<a [^>]*>[^<]*<\/a>/, generator: -> h {
    a = h[:url]
    if h[:url] =~ /<a [^>]*href="([^"]*)"[^>]*>([^<]*)<\/a>/
      h[:url] = h[:open] = $1
      h[:face] = $2
    end
    h
  })
end

module Plugin::Worldon
  # TODO: タグとかacctとかをいい感じにする
  MastodonEntity = Diva::Entity::AnchorLinkEntity
end
