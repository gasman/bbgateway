#!/usr/local/bin/ruby

require "models"
require "wos_scraper"
require "usenet_format"

def posted_today?(crap_timestamp)
  crap_timestamp.match(/(Hours?|Minutes?) Ago$/)
end

puts "Beginning fetch of WOS forums at #{Time.now}"
STDOUT.flush

fresh_forums = []
for forum in WosScraper.forums
  if (Newsgroup.find_by_name(forum[:name]))
    if !Article.find_by_source_post(forum[:last_post_id])
      puts "New posts found in forum #{forum[:name]}"
      STDOUT.flush
      fresh_forums << forum
    end
  else
    Newsgroup.create(:name => forum[:name])
    puts "Created newsgroup #{forum[:name]}"
    STDOUT.flush
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
        STDOUT.flush
        thread[:forum] = forum
        fresh_threads << thread
      elsif thread[:sticky]
        puts "Ignoring sticky thread '#{thread[:title]}'"
        STDOUT.flush
      else
        puts "Encountered stale thread '#{thread[:title]}' - finished with #{forum[:name]}"
        STDOUT.flush
        seen_all_new_threads = true
        break
      end
    end
    page += 1
  end until seen_all_new_threads
end

new_posts = {} # indexed by post ID
for thread in fresh_threads
  post_page = WosScraper.post_page_from_post_id(thread[:last_post_id])
  page_number = post_page[:page_number]
  seen_all_new_posts = false
  while true
    puts "Looking for new posts on page #{page_number} of thread '#{thread[:title]}'"
    STDOUT.flush
    for post in post_page[:posts]
      if (!Article.find_by_source_post(post[:id])) and posted_today?(post[:crap_timestamp])
        post[:forum] = thread[:forum]
        post[:subject] = (page_number == 1 && post == post_page[:posts].first ? '' : 'Re: ') + thread[:title]
        new_posts[post[:id]] = post
      else
        seen_all_new_posts = true
      end
    end
    break if page_number == 1 or seen_all_new_posts
    page_number -= 1
    post_page = WosScraper.post_page_from_thread_id(thread[:id], page_number)
  end
end

puts "Found #{new_posts.size} new posts. Annotating..."
STDOUT.flush

annotated_posts = []
until new_posts.empty?
  post_id = new_posts.keys.first
  puts "Deriving annotations from post #{post_id}"
  STDOUT.flush
  tmap = WosScraper.thread_map(post_id)
  indent_map = []
  for annotation in tmap
    indent_map[annotation[:indent]] = annotation
    next unless (post = new_posts[annotation[:id]])
    post[:references] = indent_map[(0...annotation[:indent])].map{|a| a[:id]}
    post[:date] = annotation[:timestamp]
    puts "post #{post[:id]} posted at #{annotation[:timestamp]}, references: #{post[:references].join(' ')}"
    STDOUT.flush
    annotated_posts << new_posts.delete(post[:id])
  end
  puts
end

puts "Adding to newsfeed..."
STDOUT.flush
for post in annotated_posts
  article = Article.create_from_posting({
    "From" => "#{post[:author].gsub(/[\<\>\n\r]/, '')} <#{post[:author].gsub(/[^\w\_\-]/, '-')}@wos.invalid>",
    "Date" => post[:date],
    "Newsgroups" => post[:forum][:name],
    "Subject" => post[:subject],
    "Message-Id" => "<wos-#{post[:id]}@bbgateway.bluecanary.mine.nu>",
    "References" => post[:references].map{|id| "<wos-#{id}@bbgateway.bluecanary.mine.nu>"}.join(" ")
  }, UsenetFormat.clean_html(post[:body])) #  + post[:sig].to_s
  article.update_attribute(:source_post, post[:id])
end
puts "done."
