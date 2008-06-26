ActiveRecord::Base.allow_concurrency = true
ActiveRecord::Base.establish_connection(
	:adapter => "mysql",
	:host => "localhost",
	:username => "root",
	:password => "",
	:database => "bbgateway",
	:socket => "/var/run/mysqld/mysqld.sock"
)
