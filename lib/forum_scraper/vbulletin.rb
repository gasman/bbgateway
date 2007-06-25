require "rubygems"
require "open-uri"
require "hpricot"

module QueryString
  def QueryString.parse(qs)
    h = {}
    qs.split(/&/).each do |param|
      param_components = param.split(/=/)
      h[URI.unescape(param_components.first)] = URI.unescape(param_components.last)
    end
    h
  end
end

module ForumScraper
  module VBulletin
    Category = Struct.new(:id, :name, :forums)
    Forum = Struct.new(:id, :name, :last_post_id)
    Thread = Struct.new(:id, :title, :last_post_id)
    
    class Site
    
      # The base URL where the vBulletin installation is hosted
      attr_accessor :base_url
      # Number of seconds to wait between fetches (default 10)
      attr_accessor :fetch_delay
    
      # Creates a new object representing the vBulletin installation at base_url
      def initialize(base_url)
        @base_url = base_url
        @fetch_delay = 10
      end
      
      # The URL to the main index page
      def index_page_url
        "#{@base_url}index.php"
      end
      
      # Returns the HTML content of the index page (just the main content, minus custom headers / footers)
      def index_page_content
        content = ""
        open_slowly(index_page_url) do |f|
          begin
            line = f.readline
          rescue EOFError
            raise EOFError, "Reached end of file without finding a <!-- main --> block"
          end until line =~ /^<!-- main -->/
          
          begin
            line = f.readline
            break if line =~ /^<!-- \/main -->/
            content << line
          rescue EOFError
            raise EOFError, "Reached end of file before end of  <!-- main --> block"
          end while true
        end
          
        content
      end
      
      # Returns a breakdown of the contents of the homepage, as an array of Category objects each containing an array of Forum objects
      def index_page_objects
        html = Hpricot(index_page_content)
        
        categories = []
        categories_html = html / 'tbody td[@class="tcat"] a[@href*="forumdisplay"]'
        for cat_html in categories_html
          category_id = QueryString::parse(URI.parse(cat_html['href']).query)['f']
          cat = Category.new(category_id, cat_html.inner_text, [])
          categories << cat
          forums_html = html / "tbody[@id=\"collapseobj_forumbit_#{cat.id}\"]/tr"
          for forum_html in forums_html
            forum_title = (forum_html / :td)[1] % 'a[@href*="forumdisplay"]'
            if forum_title.nil?
              throw "no forum title for forum_html: #{forum_html}"
            end
            forum_id = QueryString::parse(URI.parse(forum_title['href']).query)['f']
            last_post_id = parse_last_post_info(last_post_info)
            cat.forums << Forum.new(forum_id, forum_title.inner_text, last_post_id)
          end
        end
        categories
      end
      
      # Returns the URL to the index page of the forum with id forum_id
      def forum_index_url(forum_id)
        "#{@base_url}forumdisplay.php?f=#{forum_id}"
      end
      
      # Returns two strings containing the HTML of the subforum listing and thread listing for the given forum index page
      def forum_index_parts(forum_id)
        subforum_list = ""
        thread_list = ""
        open_slowly(forum_index_url(forum_id)) do |f|
          until f.eof? do
            line = f.readline
            if line =~ /^<!-- sub-forum list  -->/
              begin
                until (line = f.readline) =~ /^<!-- \/ sub-forum list  -->/ do
                  subforum_list << line
                end
              rescue EOFError
                raise EOFError, "Reached end of file before end of <!-- sub-forum list --> block"
              end
            elsif line =~ /^\s+<!-- show threads -->/
              # NB this block doesn't include announcements. Probably isn't a problem (they aren't real posts).
              begin
                until (line = f.readline) =~ /^\s+<!-- end show threads -->/ do
                  thread_list << line
                end
              rescue EOFError
                raise EOFError, "Reached end of file before end of <!-- show threads --> block"
              end
            end
          end
        end
        [subforum_list, thread_list]
      end
      
      def forum_index_objects(forum_id)
        (subforums_html, threads_html) = forum_index_parts(forum_id).collect {|raw_html| Hpricot(raw_html)}
        subforum_rows = subforums_html / :tbody
        # Just to piss me off, they decided not to make this match the structure on the main index page.
        # The ones we're interested in are the immediate child forums, which are the ones with a colspan=2
        # with a table in it.
        subforums = []
        for subforum_row in subforum_rows
          next unless subforum_row % 'tr/td/table'
          forum_title = (subforum_row / 'tr/td/table/tr/td')[2] % 'a[@href*="forumdisplay"]'
          if forum_title.nil?
            throw "no forum title for subforum: #{subforum_row}"
          end
          forum_id = QueryString::parse(URI.parse(forum_title['href']).query)['f']          
          last_post_info = (subforum_row / 'tr/td')[1] % 'div.smallfont'
          last_post_id = parse_last_post_info(last_post_info)
          subforums << Forum.new(forum_id, forum_title.inner_text, last_post_id)
        end
        threads = []
        for thread_row in (threads_html / 'tbody/tr')
          thread_title = thread_row % 'td[@id^="td_threadtitle_"] a[@href*="showthread"]'
          thread_id = QueryString::parse(URI.parse(thread_title['href']).query)['t']
          last_post_link = thread_row % 'td[@title^="Replies:"]/div.smallfont/a[@href*="showthread"]'
          last_post_id = QueryString::parse(URI.parse(last_post_link['href']).query)['p']
          threads << Thread.new(thread_id, thread_title.inner_text, last_post_id)
        end
        [subforums, threads]
      end
      
    private
      
      # Opens an IO stream to the specified URL, ensuring that the rate of requests to the server
      # is limited as determined by fetch_delay
      def open_slowly(url)
        @last_request ||= nil
        while (!@last_request.nil? && @last_request > Time.now - @fetch_delay)
          sleep 1
        end
        begin
          if block_given?
            response = open(url) do |f|
              yield(f)
            end
          else
            response = open(url)
          end
        ensure
          @last_request = Time.now
        end
        response
      end
      
      # Parse the Hpricot-ified div.smallfont element containing information about the last post in a forum,
      # and return the ID of that last post
      def parse_last_post_info(last_post_info)
        return nil if last_post_info.nil?
        if (last_post_info % :table)
          # for a minority of sites (eg http://www.hardforum.com/), last post link is embedded in another table
          last_post_link = (last_post_info / 'table td.smallfont')[1] % 'a[@href*="showthread"]'
        else
          last_post_link = (last_post_info / 'div')[2] % 'a[@href*="showthread"]'
        end
        QueryString::parse(URI.parse(last_post_link['href']).query)['p']
      end
      
    end
  end
end
