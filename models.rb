require "rubygems"
require_gem "activerecord"

require "database"

class Newsgroup < ActiveRecord::Base
  has_many :article_placements
  has_many :articles, :through => :article_placements
  
  def article(placement_id)
    article_placements.find_by_placement_id(placement_id, :include => {:article => :headers}).article
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
  
  def overview(min, max = nil)
    sql = <<ENDSQL
      SELECT
        article_placements.placement_id,
        hdr_subject.value AS h_subject,
        hdr_from.value AS h_from,
        hdr_date.value AS h_date,
        hdr_message_id.value AS h_message_id,
        hdr_references.value AS h_references,
        LENGTH(articles.body) AS byte_count,
        hdr_lines.value AS line_count,
        hdr_xref.value AS h_xref
      FROM
        articles
        INNER JOIN article_placements ON (articles.id = article_placements.article_id)
        LEFT OUTER JOIN headers hdr_subject ON (articles.id = hdr_subject.article_id AND hdr_subject.name = 'Subject')
        LEFT OUTER JOIN headers hdr_from ON (articles.id = hdr_from.article_id AND hdr_from.name = 'From')
        LEFT OUTER JOIN headers hdr_date ON (articles.id = hdr_date.article_id AND hdr_date.name = 'Date')
        LEFT OUTER JOIN headers hdr_message_id ON (articles.id = hdr_message_id.article_id AND hdr_message_id.name = 'Message-Id')
        LEFT OUTER JOIN headers hdr_references ON (articles.id = hdr_references.article_id AND hdr_references.name = 'References')
        LEFT OUTER JOIN headers hdr_lines ON (articles.id = hdr_lines.article_id AND hdr_lines.name = 'Lines')
        LEFT OUTER JOIN headers hdr_xref ON (articles.id = hdr_xref.article_id AND hdr_xref.name = 'Xref')
ENDSQL

    if max.nil?
      Article.find_by_sql(["#{sql} WHERE article_placements.newsgroup_id = ? AND article_placements.placement_id >= ? ORDER BY article_placements.placement_id", self.id, min])
    else
      Article.find_by_sql(["#{sql} WHERE article_placements.newsgroup_id = ? AND article_placements.placement_id >= ? AND article_placements.placement_id <= ? ORDER BY article_placements.placement_id", self.id, min, max])
    end
  end
  
end

class ArticlePlacement < ActiveRecord::Base
  belongs_to :article
  belongs_to :newsgroup
end

class Header < ActiveRecord::Base
  belongs_to :article
end

class Article < ActiveRecord::Base
  has_many :article_placements
  has_many :newsgroups, :through => :article_placements
  has_many :headers
  
  def self.create_from_posting(raw_headers, body)
    article = Article.new(:body => body)
    article.save!

    # recreate headers struct with standard Foo-Bar capitalisation on keys
    headers = {}
    raw_headers.each do |key, value|
      headers[self.capitalise(key)] = value
    end

    headers['Message-Id'] ||= "<article-#{article.id}@bbgateway.bluecanary.mine.nu>"
    headers['Path'] ||= "bluecanary!not-for-mail"

    group_names = headers['Newsgroups'].split(/\,\s*/)
    group_names.uniq.each do |name|
      if (group = Newsgroup.find_by_name(name))
        article.article_placements << ArticlePlacement.new do |placement|
          placement.newsgroup = group
          placement.placement_id = (group.last_id || 0) + 1
        end
      end
    end

    headers['Xref'] = "bluecanary.mine.nu " + article.article_placements.map{|placement| "#{placement.newsgroup.name}:#{placement.id}" }.join(" ")
    headers['Lines'] = body.split(/\n/).length
    headers['Date'] ||= Time.new
    headers['Date'] = self.to_rfc850_date(headers['Date'])

    headers.each do |key, value|
      article.headers << Header.new(:name => self.capitalise(key), :value => value)
    end

    article.save!
    article
  end
  
  def message_id
    @message_id ||= headers.detect{|h| h.name == 'Message-Id'}.value
  end
  
  def header_lines
    # FIXME: sanitize name and value
    headers.collect{|h| "#{h.name}: #{h.value}"}
  end
  def header_text
    header_lines.join("\n")
  end
  
  private
    def self.capitalise(str)
      str.downcase.gsub(/\b\w/) {|char| char.upcase}
    end
    
    def self.to_rfc850_date(date)
      date.is_a?(String) ? date : date.strftime("%a, %d %B %Y %H:%M:%S %z")
    end
end
