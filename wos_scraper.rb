require "rubygems"
require "open-uri"
require "hpricot"

module WosScraper

  def WosScraper.clean_string(str)
    str.downcase.gsub(/\W+/, '-')
  end

  # get list of newsgroups and last post from front page
  def WosScraper.forums
    wos_index = Hpricot(open("http://www.worldofspectrum.org/forums/index.php"))
    forum_list_rows = wos_index / "table:eq(1) tbody tr"
    category = nil
    forums = []
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
        forums << {:name => newsgroup_name, :forum_id => forum_id, :last_post_id => last_post_id}
      end
    end
    
    forums
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
      last_post_timestamp = (row % "td:eq(3) div > *").to_s.strip
      is_sticky = (row % "img[@src *= 'sticky']") ? true : false
      threads << {:title => title, :id => thread_id,
        :last_post_id => last_post_id, :last_post_timestamp => last_post_timestamp, :sticky => is_sticky}
    end
    
    threads
  end
  
  def WosScraper.post_page_from_post_id(post_id)
    page = Hpricot(open("http://www.worldofspectrum.org/forums/showthread.php?p=#{post_id}"))
    post_page(page)
  end
  
  def WosScraper.post_page_from_thread_id(thread_id, page)
    page = Hpricot(open("http://www.worldofspectrum.org/forums/showthread.php?t=#{thread_id}&page=#{page}"))
    post_page(page)
  end

  def WosScraper.post_page(page)
    post_tables = page / "table.tborder[@id ^= 'post']"
    posts = []
    for tbl in post_tables
      post_id = tbl['id'].match(/^post(\d+)$/)[1].to_i
      crap_timestamp = (tbl % "td.thead").inner_text.strip
      author = (tbl % ".bigusername").inner_text
      body = tbl % "div[@id ^= 'post_message_']"
      sig = tbl % "div[@id ^= 'post_message_'] ~ div"
      posts << {:id => post_id, :crap_timestamp => crap_timestamp, :author => author, :body => body, :sig => sig}
    end
    page_number_block = page % "span[@title ^= 'Showing results'] strong"
    page_number = page_number_block.nil? ? 1 : page_number_block.inner_text.to_i
    
    { :page_number => page_number, :posts => posts }
  end

end