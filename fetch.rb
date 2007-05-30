#!/usr/local/bin/ruby

require "models"
require "wos_scraper"

for group in WosScraper.newsgroups
  puts "Threads in #{group[:name]}:"
  WosScraper.threads(group[:forum_id], 1).each do |thread|
    puts "#{thread[:sticky] ? '* ' : ''}#{thread[:id]}: #{thread[:title]}"
  end
  puts
end

#forums = wos_index / "tr[td.alt1Active[a[@href*='forumdisplay.php']]]"
#
#forums.each do |forum|
#  link = forum.at("td.alt1Active a[@href*='forumdisplay.php']")
#  p link
#  newsgroup_name = make_newsgroup_name(link.inner_text)
##  forum_id = (link['href'].match(/f=(\d+)/)[1]).to_i
##  if (group = Newsgroup.find_by_name(newsgroup_name))
#    puts "found newsgroup #{newsgroup_name}"
##  else
##    group = Newsgroup.create(:name => newsgroup_name)
##    puts "created newsgroup #{newsgroup_name}"
##  end
#end
