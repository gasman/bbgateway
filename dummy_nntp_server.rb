class DummyNNTPServer < NNTPServer

  def groups
    {
      'comp.sys.sinclair' => Group.new('comp.sys.sinclair')
    }
  end
  
end

class Group
  attr_reader :name, :articles

  def initialize(name)
    @name = name
    # a bit naughty to have a message with ID 0. Oh well.
    @articles = [Article.new(0), Article.new(1), Article.new(2), Article.new(3), Article.new(4), Article.new(5)]
  end
end

class Article
  attr_reader :id, :message_id
  
  def initialize(id)
    @id = id
    @message_id = "<message-#{id}@example.com>"
  end
  
  def headers
    <<CUT
Path: bluecanary
Newsgroups: comp.sys.sinclair
Date: Sun, 20 May 2007 20:53:32 +0100
From: Nick Humphries <nickjunk@egyptus.co.uk>
Subject: Re: Does anybody want to talk about Sinclair computers at CSS or not?
Message-ID: #{@message_id}
CUT
  end
  
  def body
    <<CUT
Hello,
I am message number #{@id}.
CUT
  end
  
end