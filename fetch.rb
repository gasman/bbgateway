#!/usr/local/bin/ruby

require "models"
require "wos_scraper"

def posted_today?(crap_timestamp)
  crap_timestamp.match(/(Hours?|Minutes?) Ago$/)
end

fresh_forums = []
for forum in WosScraper.forums
  if (Newsgroup.find_by_name(forum[:name]))
    if !Article.find_by_source_post(forum[:last_post_id])
      puts "New posts found in forum #{forum[:name]}"
      fresh_forums << forum
    end
  else
    Newsgroup.create(:name => forum[:name])
    puts "Created newsgroup #{forum[:name]}"
    fresh_forums << forum
  end
end

fresh_threads = []
for forum in fresh_forums
  page = 1
  seen_all_new_threads = false
  begin
    threads = WosScraper.threads(forum[:forum_id], page)
    for thread in threads
      if (!Article.find_by_source_post(thread[:last_post_id])) and posted_today?(thread[:last_post_timestamp])
        puts "New posts found in thread '#{thread[:title]}'"
        thread[:forum] = forum
        fresh_threads << thread
      elsif thread[:sticky]
        puts "Ignoring sticky thread '#{thread[:title]}'"
      else
        puts "Encountered stale thread '#{thread[:title]}' - finished with #{forum[:name]}"
        seen_all_new_threads = true
        break
      end
    end
    page += 1
  end until seen_all_new_threads
end


#    puts "found newsgroup #{newsgroup_name}"
#  puts "Threads in #{group[:name]}:"
#  WosScraper.threads(group[:forum_id], 1).each do |thread|
#    puts "#{thread[:sticky] ? '* ' : ''}#{thread[:id]}: #{thread[:title]}"
#    page = WosScraper.post_page_from_post_id(thread[:last_post_id])
#    puts "Posts on page #{page[:page_number]}:"
#    page[:posts].each do |post|
#      puts "  #{post[:id]}: #{post[:author]}, #{post[:crap_timestamp]}"
#    end
#  end
#  puts
#end
