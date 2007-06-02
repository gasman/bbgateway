#!/usr/local/bin/ruby

# Populate article_date field of articles table based on Date headers

require "models"
require "ParseDate"

articles = Article.find(:all, :conditions => 'article_date IS NULL', :include => :headers)
for article in articles
	date_string = article.headers.detect{|h| h.name == 'Date'}.value
	article_date = Time.mktime(*ParseDate.parsedate(date_string))
	article.update_attribute(:article_date, article_date)
end
