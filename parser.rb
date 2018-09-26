require 'cgi' # unescapeHTML

module Plugin::Worldon::Parser
  def self.dehtmlize(html)
    result = html
      .gsub(%r!</p><p>!) { "\n\n" }
      .gsub(%r!<span class="ellipsis">([^<]*)</span>!) {|s| $1 + "..." }
      .gsub(%r!^<p>|</p>|<span class="invisible">[^<]*</span>|</?span[^>]*>!, '')
      .gsub(/<br[^>]*>|<p>/) { "\n" }
      .gsub(/&apos;/) { "'" }
    result
  end

  def self.dictate_score(html, mentions: [], emojis: [], media_attachments: [])
    desc = dehtmlize(html)

    score = []

    # リンク処理
    # TODO: user_detail_viewを作ったらacctをAccount Modelにする
    pos = 0
    anchor_re = %r|<a href="(?<url>[^"]*)"(?: class="(?<class>[^"]*)")?(?: rel="(?<rel>[^"]*)")?[^>]*>(?<text>[^<]*)</a>|
    urls = []
    while m = anchor_re.match(desc, pos)
      anchor_begin = m.begin(0)
      anchor_end = m.end(0)
      if pos < anchor_begin
        score << Plugin::Score::TextNote.new(description: CGI.unescapeHTML(desc[pos...anchor_begin]))
      end
      url = Diva::URI.new(CGI.unescapeHTML(m["url"]))
      if m["text"][0] == '#' || (score.last.to_s[-1] == '#')
        score << Plugin::Worldon::Tag.new(name: CGI.unescapeHTML(m["text"]).sub(/\A#/, ''))
      else
        account = nil
        if mentions.any? { |mention| mention.url == url }
          mention = mentions.lazy.select { |mention| mention.url == url }.first
          acct = Plugin::Worldon::Account.regularize_acct_by_domain(mention.url.host, mention.acct)
          account = Plugin::Worldon::Account.findbyacct(acct)
        end
        if account
          score << account
        else
          link_hash = {
            description: CGI.unescapeHTML(m["text"]),
            uri: url,
            worldon_link_attr: Hash.new,
          }
          link_hash[:worldon_link_attr][:class] = m["class"].split(' ') if m["class"]
          link_hash[:worldon_link_attr][:rel] = m["rel"].split(' ') if m["rel"]
          score << Plugin::Score::HyperLinkNote.new(link_hash)
        end
      end
      urls << url
      pos = anchor_end
    end
    if pos < desc.size
      score << Plugin::Score::TextNote.new(description: CGI.unescapeHTML(desc[pos...desc.size]))
    end

    # 添付ファイル用のwork around
    # TODO: mikutter本体側が添付ファイル用のNoteを用意したらそちらに移行する
    if media_attachments.size > 0
      media_attachments
        .select {|attachment|
          !urls.include?(attachment.url.to_s) && !urls.include?(attachment.text_url.to_s)
        }
        .each {|attachment|
          score << Plugin::Score::TextNote.new(description: "\n")

          description = attachment.text_url
          if !description
            description = attachment.url
          end
          score << Plugin::Score::HyperLinkNote.new(description: description, uri: attachment.url)
        }
    end

    score = score.flat_map do |note|
      if !note.is_a?(Plugin::Score::TextNote)
        [note]
      else
        emoji_score = Enumerator.new{|y|
          dictate_emoji(note.description, emojis, y)
        }.first.to_a
        if emoji_score.size > 0
          emoji_score
        else
          [note]
        end
      end
    end

    description = score.inject('') do |acc, note|
      acc + note.description
    end

    [description, score]
  end

  # 与えられたテキスト断片に対し、emojisでEmojiを置換するscoreを返します。
  def self.dictate_emoji(text, emojis, yielder)
    score = emojis.inject(Array(text)){ |fragments, emoji|
      shortcode = ":#{emoji.shortcode}:"
      fragments.flat_map{|fragment|
        if fragment.is_a?(String)
          if fragment === shortcode
            [emoji]
          else
            sub_fragments = fragment.split(shortcode).flat_map{|str|
              [str, emoji]
            }
            sub_fragments.pop unless fragment.end_with?(shortcode)
            sub_fragments
          end
        else
          [fragment]
        end
      }
    }.map{|chunk|
      if chunk.is_a?(String)
        Plugin::Score::TextNote.new(description: chunk)
      else
        chunk
      end
    }

    if (score.size > 1 || score.size == 1 && !score[0].is_a?(Plugin::Score::TextNote))
      yielder << score
    end
  end
end
