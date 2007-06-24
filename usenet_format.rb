module UsenetFormat

  SMILEYS = {
    'images/smilies/icon_biggrin.gif' => ':-D',
    'images/smilies/icon_confused.gif' => '?:-/',
    'images/smilies/icon_cool.gif' => '8)',
    'images/smilies/icon_cry.gif' => ":'-(",
    'images/smilies/icon_eek.gif' => ':-o',
    'images/smilies/icon_evil.gif' => '>:-[',
    'images/smilies/icon_frown.gif' => ':(',
    'images/smilies/icon_lol.gif' => ':-D',
    'images/smilies/icon_mad.gif' => '>:-(',
    'images/smilies/icon_razz.gif' => ':P',
    'images/smilies/icon_redface.gif' => ':-o',
    'images/smilies/icon_rolleyes.gif' => ':rolleyes:',
    'images/smilies/icon_smile.gif' => ':)',
    'images/smilies/icon_wink.gif' => ';)',
    'images/smilies/confused.gif' => '?:-/',
    'images/smilies/rolleyes.gif' => ':rolleyes:'
  }

  # adapted from http://macromates.com/blog/2006/wrapping-text-with-regular-expressions/
  def UsenetFormat.wrap_text(txt, quote_level = 0)
    quote_prefix = (('>' * quote_level) + ' ').lstrip
    # special case for empty string - always output a line
    if txt == ''
      quote_prefix + "\n"
    else
      col = 80 - quote_prefix.length
      txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
        "#{quote_prefix}\\1\\3\n") 
    end
  end
  
  def UsenetFormat.inlines_to_text(inlines, links)
    inlines.map{|i|
      if i.elem?
        if i.name == 'img'
          SMILEYS[i['src']] || "(Image: #{i['src']})"
        elsif i.name == 'a'
          link_ref = links.size
          linktext = inlines_to_text(i.children, links)
          if linktext == i['href'] or linktext == (i['href'][0,36] + '...' + i['href'][-14,14])
            i['href']
          else
            links << i['href']
            "#{linktext} [#{link_ref}]"
          end
        elsif i.name == 'i'
          "/#{inlines_to_text(i.children, links)}/"
        elsif i.name == 'b'
          "*#{inlines_to_text(i.children, links)}*"
        elsif i.name == 'u'
          "_#{inlines_to_text(i.children, links)}_"
        elsif i.name == 'font'
          inlines_to_text(i.children, links)
        else
          i.to_s # output raw HTML
        end
      else
        i.to_s
      end
    }.join
  end
  
  def UsenetFormat.expand_entities(str)
    str.gsub(/&lt;/, '<').gsub(/&gt;/, '>').gsub(/&quot;/, "\"").gsub(/&\#(\d+);/){$1.to_i.chr}.gsub(/&amp;/, '&')
  end
  
  def UsenetFormat.render_inlines(inlines, quote_level, links)
    wrap_text(expand_entities(inlines_to_text(inlines, links).gsub(/\s+/, ' ')).strip, quote_level)
  end
  
  def UsenetFormat.clean_html_traverse(doc, quote_level, links)
    text = ''
    inlines = []
    doc.each_child do |node|
      if node.elem?
        if node.name == 'br'
          text += render_inlines(inlines, quote_level, links)
          inlines = []
        elsif node.name == 'div'
          next if node.classes.include?('smallfont')
            text += render_inlines(inlines, quote_level, links)
            inlines = []
          if node % "div.smallfont[text()='Quote:']"
            divs = node / "/table/tr/td/div"
            if divs.size == 2
              text += "#{(divs[0] % 'strong').inner_text} wrote:\n"
              text += clean_html_traverse(divs[1], quote_level + 1, links) + "\n"
            else
              text += clean_html_traverse(node % "/table/tr/td", quote_level + 1, links) + "\n"
            end
          else
            text += clean_html_traverse(node, quote_level, links)
          end
        elsif node.name == 'font'
          text += render_inlines(inlines, quote_level, links)
          inlines = []
          text += clean_html_traverse(node, quote_level, links)
        elsif node.name == 'pre'
          text += render_inlines(inlines, quote_level, links)
          inlines = []
          text += expand_entities(node.inner_text)
        elsif node.name == 'ul'
          text += render_inlines(inlines, quote_level, links)
          inlines = []
          (node / '/li').each do |li|
            text += "* " + clean_html_traverse(li, quote_level, links)
          end
        else
          inlines << node
        end
      else
        inlines << node
      end
    end
    text += render_inlines(inlines, quote_level, links)
    text
  end
  
  def UsenetFormat.clean_html(doc)
    links = []
    txt = clean_html_traverse(doc, 0, links)
    txt.sub!(/^\n+/, '')
    unless links.empty?
      txt += "\n"
      links.each_with_index do |url, i|
        txt += "[#{i}] #{expand_entities(url)}\n"
      end
    end
    txt
  end
  
end
