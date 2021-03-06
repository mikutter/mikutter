require 'cgi' # unescapeHTML

module Plugin::Mastodon::Parser
  def self.dehtmlize(html)
    result = html
      .gsub(%r!</p><p>!) { "\n\n" }
      .gsub(%r!<span class="ellipsis">([^<]*)</span>!) {|s| $1 + "..." }
      .gsub(%r!^<p>|</p>|<span class="invisible">[^<]*</span>|</?span[^>]*>!, '')
      .gsub(/<br[^>]*>|<p>/) { "\n" }
      .gsub(/&apos;/) { "'" }
    result
  end

  def self.dictate_score(html, mentions: [], emojis: [], media_attachments: [], poll: nil)
    desc = dehtmlize(html)

    score = []

    pos = 0
    anchor_re = %r|<a(?<attr1>[^>]*) href="(?<url>[^"]*)"(?<attr2>[^>]*)>(?<text>[^<]*)</a>|
    appeared_urls = Set.new

    while m = anchor_re.match(desc, pos)
      anchor_begin = m.begin(0)
      anchor_end = m.end(0)
      if pos < anchor_begin
        score << Plugin::Score::TextNote.new(description: CGI.unescapeHTML(desc[pos...anchor_begin]))
      end
      url = Diva::URI.new(CGI.unescapeHTML(m["url"]))
      if m["text"][0] == '#' || (score.last.to_s[-1] == '#')
        score << Plugin::Mastodon::Tag.new(name: CGI.unescapeHTML(m["text"]).sub(/\A#/, ''))
      else
        account = nil
        if mentions.any? { |mention| mention.url == url }
          mention = mentions.lazy.select { |mention| mention.url == url }.first
          acct = Plugin::Mastodon::Account.regularize_acct_by_domain(mention.url.host, mention.acct)
          account = Plugin::Mastodon::Account.findbyacct(acct)
        end
        if account
          score << account
        else
          link_hash = {
            description: CGI.unescapeHTML(m["text"]),
            uri: url,
            mastodon_link_attr: Hash.new,
          }
          attrs = m["attr1"] + m["attr2"]
          attr_pos = 0
          attr_re = %r| (?<name>[^=]+)="(?<value>[^"]*)"|
          while m2 = attr_re.match(attrs, attr_pos)
            attr_name = m2["name"].to_sym
            attr_value = m2["value"]
            if [:class, :rel].include? attr_name
              link_hash[:mastodon_link_attr][attr_name] = attr_value.split(' ')
            else
              link_hash[:mastodon_link_attr][attr_name] = attr_value
            end
            attr_pos = m2.end(0)
          end
          score << Plugin::Score::HyperLinkNote.new(link_hash)
        end
      end
      appeared_urls << url
      pos = anchor_end
    end
    if pos < desc.size
      score << Plugin::Score::TextNote.new(description: CGI.unescapeHTML(desc[pos...desc.size]))
    end

    # 添付ファイル用のwork around
    # TODO: mikutter本体側が添付ファイル用のNoteを用意したらそちらに移行する
    media_attachments.reject { |a|
      appeared_urls.include?(a.url.to_s) || appeared_urls.include?(a.text_url.to_s)
    }.each do |attachment|
      url = attachment.url
      score <<
        Plugin::Score::TextNote.new(description: "\n") <<
        Plugin::Score::HyperLinkNote.new(
          description: attachment.text_url || url,
          uri: url,
          reference: Plugin.collect(:photo_filter, url).first
        )
    end

    if poll
      y = []
      poll.options.each do |opt|
        y << '○ %{title}' % {title: opt.title}
      end
      y << '%{count}票' % {count: poll.votes_count}
      if poll.expires_at
        y << '%{expire}に終了' % {expire: poll.expires_at.strftime("%Y-%m-%d %H:%M:%S")}
      end
      score << Plugin::Score::TextNote.new(description: "\n" + y.join("\n"))
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
      desc = note.is_a?(Plugin::Score::HyperLinkNote) ? note.uri.to_s : note.description
      acc + desc
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
