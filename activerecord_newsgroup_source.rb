require "rubygems"
require_gem "activerecord"

ActiveRecord::Base.establish_connection(
	:adapter => "mysql",
	:host => "localhost",
	:username => "root",
	:password => "",
	:database => "bbgateway"
)

class NewsgroupSource
  # TODO: prefetch first_id, last_id, article_count
  def groups(opts = {})
    if opts[:since] && opts[:prefix]
      conditions = ["created_at >= ? AND name LIKE ?", opts[:since], "#{opts[:prefix]}.%"]
    elsif opts[:since]
      conditions = ["created_at >= ?", opts[:since]]
    elsif opts[:prefix]
      conditions = ["name LIKE ?", "#{opts[:prefix]}.%"]
    else
      conditions = nil
    end
    Newsgroup.find(:all, :conditions => conditions)
  end
  
  def group(name)
    Newsgroup.find_by_name(name)
  end
  
  def article(message_id)
    Article.find_by_message_id(message_id)
  end
end

class Newsgroup < ActiveRecord::Base
  has_many :article_placements
  has_many :articles, :through => :article_placements
  
  def article(placement_id)
    article_placements.find_by_placement_id(placement_id, :include => :article).article
  end
  
  def first_id
    article_placements.minimum('placement_id')
  end
  
  def last_id
    article_placements.maximum('placement_id')
  end
  
  def article_count
    article_placements.count
  end
  
  def id_before(old_id)
    article_placements.maximum('placement_id', :conditions => ['placement_id < ?', old_id])
  end
  
  def id_after(old_id)
    article_placements.minimum('placement_id', :conditions => ['placement_id > ?', old_id])
  end
  
end

class ArticlePlacement < ActiveRecord::Base
  belongs_to :article
  belongs_to :newsgroup
end

class Article < ActiveRecord::Base
  has_many :article_placements
  has_many :newsgroups, :through => :article_placements
  
  def headers
    <<CUT
Path: bluecanary!not-for-mail
Newsgroups: #{newsgroups.collect{|g| g.name}.join(',')}
Date: Sun, 20 May 2007 20:53:32 +0100
From: #{author}
Subject: #{subject}
Message-ID: #{message_id}
CUT
  end
end
