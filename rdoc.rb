# 
# RDoc Rake tasks for ThingFish
# $Id$
# 

require 'rake/rdoctask'

begin
	gem 'darkfish-rdoc'

	Rake::RDocTask.new do |rdoc|
		rdoc.rdoc_dir = 'docs'
		rdoc.title    = "#{PKG_NAME} - #{PKG_SUMMARY}"
		rdoc.options += RDOC_OPTIONS + [ '-f', 'darkfish' ]

		rdoc.rdoc_files.include 'README'
		rdoc.rdoc_files.include LIB_FILES.collect {|f| f.to_s }
	end
rescue LoadError, Gem::Exception => err
	if !Object.const_defined?( :Gem )
		require 'rubygem'
		retry
	end
	
	task :no_darkfish do
		fail "Could not generate RDoc: %s" % [ err.message ]
	end
	task :docs => :no_darkfish
end

