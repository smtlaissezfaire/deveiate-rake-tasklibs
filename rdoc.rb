# 
# RDoc Rake tasks for ThingFish
# $Id$
# 

require 'rake/rdoctask'
$have_darkfish = false

begin
	require 'darkfish-rdoc'
	$have_darkfish = true
rescue LoadError => err
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		gem 'darkfish-rdoc'
		retry
	end
	
	log "No DarkFish: %s: %s" % [ err.class.name, err.message ]
	trace "Backtrace:\n  %s" % [ err.backtrace.join("\n  ") ]
end

Rake::RDocTask.new do |rdoc|
	rdoc.rdoc_dir = 'docs/html'
	rdoc.title    = "#{PKG_NAME} - #{PKG_SUMMARY}"
	rdoc.options += RDOC_OPTIONS + [ '-f', 'darkfish' ] if $have_darkfish

	rdoc.rdoc_files.include 'README'
	rdoc.rdoc_files.include LIB_FILES.collect {|f| f.to_s }
end
