require 'socket'

class ClientQuitError < RuntimeError; end

class NNTPServer

  def initialize(opts)
    @port = opts[:port] || 119
    @host = opts[:host]
  end
  
  def start
    server = @host ? TCPServer.open(@host, @port) : TCPServer.open(@port)

    port = server.addr[1]
    addrs = server.addr[2..-1].uniq

    log "listening on #{addrs.collect{|a|"#{a}:#{port}"}.join(' ')}"

    loop do
      socket = server.accept

      Thread.start(socket) do |s| # one thread per client
        begin
          NNTPSession.new(self, s)
        rescue Exception
          $stderr.puts "Exception: #{$!}"
          $stderr.puts $!.backtrace
          raise
        end
      end

    end
  end
  
  def log(message)
    puts "*** #{message}"
  end
  
  def groups
    {}
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
                if @group.articles[article_number.to_i]
                  @article = @group.articles[article_number.to_i]
                else
                  send_status "423 no such article number in this group"
                  next
                end
              end
              
              case command.downcase
              when 'article'
                send_status "220 #{@article.id} #{@article.message_id} article retrieved - head and body follow"
                text_response do |t|
                  t.write @article.headers
                  t.write
                  t.write @article.body
                end
              when 'body'
                send_status "222 #{@article.id} #{@article.message_id} article retrieved - body follows"
                text_response do |t|
                  t.write @article.body
                end
              when 'head'
                send_status "221 #{@article.id} #{@article.message_id} article retrieved - head follows"
                text_response do |t|
                  t.write @article.headers
                end
              when 'stat'
                send_status "223 #{@article.id} #{@article.message_id} article retrieved - request text separately"
              end
              
            when /^group\s+(\S+)/i
              group_name = $1
              if @server.groups.include?(group_name)
                @group = @server.groups[group_name]
                send_status "211 #{@group.articles.size} #{@group.articles.first.id} #{@group.articles.last.id} #{@group.name} group selected"
              else
                send_status "411 no such news group"
              end
            when /^list\b/i
              send_status "215 list of newsgroups follows"
              text_response do |t|
                @server.groups.each_value do |group|
                  if group.articles.empty?
                    # put last_id < first_id to indicate an empty group
                    t.write "#{group.name} 1 2 n"
                  else
                    t.write "#{group.name} #{group.articles.last.id} #{group.articles.first.id} n"
                  end
                end
              end
            when /^quit\b/i
              send_status "205 closing connection - goodbye!"
              raise ClientQuitError
            else
              send_status "500 command not recognized"
            end
          end

        rescue ClientQuitError
          log "#{@name}:#{@port} disconnected"

        ensure
          @socket.close # close socket on error
        end

        log "done with #{@name}:#{@port}"
      end
      
      def send_status(str)
        @socket.write(str.chomp + "\r\n")
        log_response(str)
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
          @session.log_response line
          @session.socket.write((line =~ /^\./ ? ".#{line}" : line) + "\r\n")
        end
      end
    end

end