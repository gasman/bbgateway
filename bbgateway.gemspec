spec = Gem::Specification.new do |s|
	s.name = 'bbgateway'
	s.version = '0.0.3'
	s.summary = 'Web bulletin board to NNTP gateway'
	s.description = 'Utilities for scraping content from web-based bulletin boards and providing it via NNTP'
	s.add_dependency('activerecord', '>= 1.15.5')
	s.add_dependency('hpricot', '>= 0.6')
	s.add_dependency('daemons', '>= 1.0.10')
	s.executables << 'bbgateway-fetch'
	s.executables << 'bbgateway-nntp'
	s.files = Dir['lib/**/*.rb'] + Dir['bin/*']
	s.has_rdoc = false
	s.author = 'Matt Westcott'
	s.email = 'matt@west.co.tt'
	s.homepage = 'http://matt.west.co.tt/'
end
