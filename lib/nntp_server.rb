require "socket"
require "models"

class ClientQuitError < RuntimeError; end

class NNTPServer

  def initialize(opts)
    @port = opts[:port] || 119
    @host = opts[:host]
    @log = opts[:log]
  end
  
  def start
    server = @host ? TCPServer.open(@host, @port) : TCPServer.open(@port)

    port = server.addr[1]
    addrs = server.addr[2..-1].uniq

    log "listening on #{addrs.collect{|a|"#{a}:#{port}"}.join(' ')}"

    begin
      loop do
        socket = server.accept

        Thread.start(socket) do |s| # one thread per client
          begin
            NNTPSession.new(self, s)
          rescue Exception
            log "Exception: #{$!}"
            $!.backtrace.each do |line|
              log line
            end
            raise
          end
        end
      end
    rescue Interrupt

    end
  end
  
  def shutdown
    log "Shutting down."
    @log.close unless @log.nil?
  end
  
  def log(message)
    puts "*** #{message}"
    unless @log.nil?
      @log.puts message
      @log.flush
    end
  end
  
  protected
  
    class NNTPSession
      attr_reader :server, :socket
    
      def initialize(server, socket)
        @server = server
        @socket = socket
        
        @port = socket.peeraddr[1]
        @name = socket.peeraddr[2]
        @addr = socket.peeraddr[3]
        
        @group = nil
        @article = nil
        @placement_id = nil
        
        @server.log "initialising session"
        
        run
      end
      
      def run
        log "receiving from #{@name}:#{@port}"
    
        send_status "201 server ready - no posting allowed"

        begin
          while line = @socket.gets # read a line at a time
            log_command(line)
            case line
            when /^\s*$/
              next
              
            when /^(article|body|head|stat)\b\s*(\d*)\s*$/i
              command = $1
              article_number = $2

              if @group.nil?
                send_status "412 no newsgroup has been selected"
                next
              end
              
              # load @article with the specified article
              if article_number.empty?
                if @article.nil?
                  send_status "420 no current article has been selected"
                  next
                end
              else
                if (article = @group.article(article_number.to_i))
                  @placement_id = article_number.to_i
                  @article = article
                else
                  send_status "423 no such article number in this group"
                  next
                end
              end
              send_article(command, @article, @placement_id)
              
            when /^(article|body|head|stat)\s*(\<[^\>]+\>)\s*$/i
              command = $1
              message_id = $2
              h = Header.find_by_name_and_value('Message-Id', message_id)
              if h.nil?
                send_status "430 no such article found"
                next
              end
              send_article(command, h.article, 0)

            when /^date\b/i
              send_status "111 #{Time.now.utc.strftime("%Y%m%d%H%M%S")}"

            when /^group\s+(\S+)/i
              group_name = $1
              if (group = Newsgroup.find_by_name(group_name))
                @group = group
                if @group.article_count > 0
                  send_status "211 #{@group.article_count} #{@group.first_id} #{@group.last_id} #{@group.name} group selected"
                else
                  # put last_id < first_id to indicate an empty group
                  send_status "211 0 2 1 #{@group.name} group selected"
                end
              else
                send_status "411 no such news group"
              end

            when /^help\b/i
              send_status "100 help text follows"
              text_response do |t|
                t.write "You are in a maze of twisty newsgroups, all alike."
                t.write "Commands recognised:"
                t.write "  article [MessageID|Number]"
                t.write "  body [MessageID|Number]"
                t.write "  date"
                t.write "  group [newsgroup]"
                t.write "  head [MessageID|Number]"
                t.write "  help"
                # t.write "  ihave"
                t.write "  last"
                t.write "  list"
                t.write "  mode reader"
                t.write "  newgroups [yy]yymmdd hhmmss [\"GMT\"|\"UTC\"]"
                t.write "  newnews newsgroups [yy]yymmdd hhmmss [\"GMT\"|\"UTC\"]"
                t.write "  next"
                t.write "  over [range]"
                # t.write "  post"
                t.write "  quit"
                t.write "  slave"
                t.write "  stat [MessageID|Number]"
                t.write "  xover [range]"
              end

            when /^ihave\s*(\<[^\>]+\>)\s*$/i
              send_status "435 article not wanted - do not send it"

            when /^last\b/i
              if @group.nil?
                send_status "412 no newsgroup selected"
                next
              end
              if @placement_id.nil?
                send_status "420 no current article has been selected"
                next
              end
              new_placement_id = @group.id_before(@placement_id)
              if new_placement_id.nil?
                send_status "422 no previous article in this group"
              else
                @placement_id = new_placement_id
                @article = @group.article(@placement_id)
                send_status "223 #{@placement_id} #{@article.message_id} article retrieved - request text separately"
              end
              
            when /^list\b/i
              send_status "215 list of newsgroups follows"
              text_response do |t|
                Newsgroup.find(:all, :order => 'name').each do |group|
                  if group.first_id.nil?
                    # put last_id < first_id to indicate an empty group
                    t.write "#{group.name} 1 2 n"
                  else
                    t.write "#{group.name} #{group.last_id} #{group.first_id} n"
                  end
                end
              end
              
            when /^mode\s+reader\b/i
              send_status "201 Posting prohibited"

            when /^newgroups\s+([\d\scgmtu]+)/i
              date = parse_numeric_datestamp($1)
              if date.nil?
                send_status "500 command not recognised"
                next
              end

              send_status "231 List of new newsgroups follows (multi-line)"
              new_groups = Newsgroup.find(:all, :conditions => ['created_at > ?', date])
              text_response do |t|
                for group in new_groups
                  t.write group.name
                end
              end

            when /^newnews\s+(\S+)\s+([\d\scgmtu]+)/i
              wildmat = $1
              date = parse_numeric_datestamp($2)
              if date.nil?
                send_status "500 command not recognised"
                next
              end
              
              articles = Article.newnews(wildmat, date)

              send_status "230 list of new articles by message-id follows"
              text_response do |t|
                for article in articles
                  t.write article.message_id
                end
              end

            when /^next\b/i
              if @group.nil?
                send_status "412 no newsgroup selected"
                next
              end
              if @placement_id.nil?
                send_status "420 no current article has been selected"
                next
              end
              new_placement_id = @group.id_after(@placement_id)
              if new_placement_id.nil?
                send_status "421 no next article in this group"
              else
                @placement_id = new_placement_id
                @article = @group.article(@placement_id)
                send_status "223 #{@placement_id} #{@article.message_id} article retrieved - request text separately"
              end

            when /^over\s+([\d\-]+)/i, /^xover\s+([\d\-]+)/i
              range = $1
              if @group.nil?
                send_status "412 No newsgroup selected"
                next
              end
              if range =~ /^(\d+)$/
                article_id = $1.to_i
                overview = @group.overview(article_id, article_id)
              elsif range =~ /^(\d+)\-$/
                overview = @group.overview($1.to_i)
              elsif range =~ /^(\d+)\-(\d+)$/
                overview = @group.overview($1.to_i, $2.to_i)
              else
                send_status "500 command not recognized"
                next
              end
              if overview.length == 0
                send_status "423 No articles in that range"
              else
                send_status "224 Overview information follows (multi-line)"
                text_response do |t|
                  for article in overview
                    t.write [article.placement_id, article.h_subject, article.h_from, article.h_date, article.h_message_id, article.h_references, article.byte_count, article.line_count, "Xref: #{article.h_xref}"].map {|h|
                      h.nil? ? '' : h.gsub(/\n\r/, '').gsub(/\t/, ' ')
                    }.join("\t")
                  end
                end
              end

            when /^post\b/i
              send_status "440 posting not allowed"

            when /^quit\b/i
              send_status "205 closing connection - goodbye!"
              raise ClientQuitError

            when /^slave\b/i
              send_status "202 slave status noted"
              
            else
              send_status "500 command not recognized"
            end
          end

        rescue ClientQuitError
          log "#{@name}:#{@port} disconnected"

        ensure
          ActiveRecord::Base.connection.disconnect!
          @socket.close # close socket on error
        end

        log "done with #{@name}:#{@port}"
      end
      
      def send_status(str)
        @socket.write(str.chomp + "\r\n")
        log_response(str)
      end
      
      def send_article(command, article, placement)
        case command.downcase
        when 'article'
          send_status "220 #{placement} #{article.message_id} article retrieved - head and body follow"
          text_response do |t|
            t.write article.header_text
            t.write
            t.write article.body
          end
        when 'body'
          send_status "222 #{placement} #{article.message_id} article retrieved - body follows"
          text_response do |t|
            t.write article.body
          end
        when 'head'
          send_status "221 #{placement} #{article.message_id} article retrieved - head follows"
          text_response do |t|
            t.write article.header_text
          end
        when 'stat'
          send_status "223 #{placement} #{article.message_id} article retrieved - request text separately"
        end
      end
      
      def parse_numeric_datestamp(str)
        if str =~ /^(\d\d\d\d)(\d\d)(\d\d)\s+(\d\d)(\d\d)(\d\d)/
          year = $1.to_i
          month = $2.to_i
          day = $3.to_i
          hour = $4.to_i
          minute = $5.to_i
          second = $6.to_i
        elsif str =~ /^(\d\d)(\d\d)(\d\d)\s+(\d\d)(\d\d)(\d\d)/
          year = $1.to_i
          month = $2.to_i
          day = $3.to_i
          hour = $4.to_i
          minute = $5.to_i
          second = $6.to_i
          current_year = Time.now.year
          century = current_year - (current_year % 100)
          year += (year <= current_year % 100 ? century : century - 100)
        else
          return nil
        end

        if str =~ /(gmt|utc)\s*$/i
          Time.gm(year, month, day, hour, minute, second)
        else
          Time.local(year, month, day, hour, minute, second)
        end
      end
      
      def log_command(str)
        log "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}] #{@addr} >>> #{str}"
      end
      def log_response(str)
        log "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}] #{@addr} <<< #{str}"
      end
      
      def log(str)
        @server.log(str)
      end
      
      def text_response(text = nil)
        if block_given?
          yield TextResponse.new(self)
        else
          TextResponse.new(self).write(text)
        end
        @socket.write(".\r\n")
      end
      
    end
    
    class TextResponse
      def initialize(session)
        @session = session
      end
      def write(text = nil)
        text = "\n" if text.nil? or text == ""
        text.each_line do |line|
          # qualify lines beginning with '.' with an escaping '.'
          line.chomp!
          # @session.log_response line
          @session.socket.write((line =~ /^\./ ? ".#{line}" : line) + "\r\n")
        end
      end
    end

end
