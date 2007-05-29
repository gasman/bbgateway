require "models"

Article.create_from_posting({
  "Newsgroups" => "comp.sys.sinclair",
  "From" => "Matthew Westcott <gasman@raww.org>",
  "Subject" => "Test"
}, "Please ignore.\nUnless you're Starglider.")

Article.create_from_posting({
  "Newsgroups" => "comp.sys.sinclair,comp.sys.cbm,rec.fly-fishing",
  "From" => "The Starglider <starglider@example.com>",
  "Subject" => "The C64 was crap"
}, "Just thought you might like to know.")
