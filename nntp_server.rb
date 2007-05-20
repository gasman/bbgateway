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
        NNTPSession.new(self, s)
      end

    end
  end
  
  def log(message)
    puts "*** #{message}"
  end
    
  protected
  
    class NNTPSession
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
            when /^quit/i
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
        @socket.puts(str)
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
      
    end

end