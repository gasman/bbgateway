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
    Forum = Struct.new(:id, :name)
    
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
      
      def index_page_objects
        html = Hpricot(index_page_content)
        
        categories = []
        categories_html = html / 'tbody td[@class="tcat"] a[@href*="forumdisplay"]'
        for cat_html in categories_html
          category_id = QueryString::parse(URI.parse(cat_html['href']).query)['f']
          cat = Category.new(category_id, cat_html.inner_text, [])
          categories << cat
          forums_html = html / "tbody[@id=\"collapseobj_forumbit_#{cat.id}\"] tr"
          for forum_html in forums_html
            forum_title = (forum_html / :td)[1] % 'a[@href*="forumdisplay"]'
            forum_id = QueryString::parse(URI.parse(forum_title['href']).query)['f']
            cat.forums << Forum.new(forum_id, forum_title.inner_text)
          end
        end
        categories
      end
      
      def open_slowly(url)
        @last_request ||= nil
        while (!@last_request.nil? && @last_request > Time.now - 10)
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
            
    end
  end
end
