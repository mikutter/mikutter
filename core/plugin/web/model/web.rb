# -*- coding: utf-8 -*-

=begin rdoc
Web上のリソースを示す汎用的なModel。
これ自体が特別な機能は提供せず、単にURLがWeb上のリソースを指し示していることを表わすために使う。

例えば、URLはWebブラウザで開くことができるが、intentは最終的に全てModelに変換できなければならないため、Modelが用意されていない多くのURLは取り扱うことができない。
=end
module Plugin::Web
  class Web < Diva::Model
    register :web

    field.uri :perma_link

    handle ->uri{ %w<http https>.include?(uri.scheme) } do |uri|
      new(perma_link: uri)
    end

    def title
      perma_link.to_s
    end
  end
end
