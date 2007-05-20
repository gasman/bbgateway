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
            when /^list\b/i
              send_status "215 list of newsgroups follows"
              text_response do |t|
                for group in @server.groups
                  t.write "#{group.name} 1 2 n"
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
      def write(text)
        text.each_line do |line|
          # qualify lines beginning with '.' with an escaping '.'
          line.chomp!
          @session.log_response line
          @session.socket.write((line =~ /^\./ ? ".#{line}" : line) + "\r\n")
        end
      end
    end

end