#!/usr/local/bin/ruby

require 'nntp_server'
require 'optparse'

nntp_options = {
  :port => 119,
  :host => ''
}

opts = OptionParser.new do |opts|
  # Cast 'delay' argument to a Float.
  opts.on("-p", "--port N", Integer, "Port number to listen on (default 119)") do |n|
    nntp_options[:port] = n
  end

  opts.on("-h", "--host [IP]", String, "Host to bind to (default all)") do |h|
    nntp_options[:host] = h
  end

  opts.on_tail("-?", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

s = NNTPServer.new(nntp_options)

s.start