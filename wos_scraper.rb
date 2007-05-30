require "rubygems"
require "open-uri"
require "hpricot"

module WosScraper

  def WosScraper.clean_string(str)
    str.downcase.gsub(/\W+/, '-')
  end

  # get list of newsgroups and last post from front page
  def WosScraper.newsgroups
    wos_index = Hpricot(open("http://www.worldofspectrum.org/forums/index.php"))
    forum_list_rows = wos_index / "table:eq(1) tbody tr"
    category = nil
    newsgroups = []
    for row in forum_list_rows
      if row % 'td.tcat'
        category = clean_string((row % "a[@href *= 'forumdisplay.php']").inner_text)
      elsif row % 'td.alt1Active'
        forum_name = (row % 'strong').inner_text
        ng_leaf_name = clean_string(forum_name)
        if category.nil? or category == ng_leaf_name
          newsgroup_name = "wos.#{ng_leaf_name}"
        else
          newsgroup_name = "wos.#{category}.#{ng_leaf_name}"
        end
        last_post_href = (row % "td:eq(2) a[img[@src *= 'lastpost']]")['href']
        last_post_id = last_post_href.match(/&amp;p=(\d+)/)[1].to_i
        forum_id = (row % "a[strong]")['href'].match(/&amp;f=(\d+)/)[1].to_i
        newsgroups << {:name => newsgroup_name, :forum_id => forum_id, :last_post_id => last_post_id}
      end
    end
    
    newsgroups
  end
  
  def WosScraper.threads(forum_id, page)
    forum_index = Hpricot(open("http://www.worldofspectrum.org/forums/forumdisplay.php?f=#{forum_id}&page=#{page}"))
    threads = []
    rows = forum_index / "table#threadslist tbody[@id *= 'threadbits_forum'] tr"
    for row in rows
      title_link = row % "a[@id *= 'thread_title_']"
      thread_id = title_link['id'].match(/^thread_title_(\d+)$/)[1].to_i
      title = title_link.inner_text
      last_post_href = (row % "a[img[@src *= 'lastpost']]")['href']
      last_post_id = last_post_href.match(/&amp;p=(\d+)/)[1].to_i
      is_sticky = (row % "img[@src *= 'sticky']") ? true : false
      threads << {:title => title, :id => thread_id, :last_post_id => last_post_id, :sticky => is_sticky}
    end
    
    threads
  end

end