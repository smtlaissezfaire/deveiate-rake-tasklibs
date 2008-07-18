# 
# Rake tasklib for testing tasks
# $Id$
# 
# Authors:
# * Michael Granger <ged@FaerieMUD.org>
# 

COVERAGE_MINIMUM = 85.0 unless defined?( COVERAGE_MINIMUM )

desc "Run all defined tests"
task :test do
	unless SPEC_FILES.empty?
		log "Running specs"
		Rake::Task['spec:quiet'].invoke
	end
	
	unless TEST_FILES.empty?
		log "Running unit tests"
		Rake::Task[:unittests].invoke 
	end
end


### RSpec specifications
begin
	gem 'rspec', '>= 1.1.3'
	require 'spec/rake/spectask'

	COMMON_SPEC_OPTS = ['-c', '-f', 's']

	### Task: spec
	Spec::Rake::SpecTask.new( :spec ) do |task|
		task.spec_files = SPEC_FILES
		task.libs += [LIBDIR]
		task.spec_opts = COMMON_SPEC_OPTS
	end


	namespace :spec do
		desc "Run rspec every time there's a change to one of the files"
		task :autotest do
			require 'autotest/rspec'

			autotester = Autotest::Rspec.new
			autotester.exceptions = %r{\.svn|\.skel}
			autotester.run
		end


		desc "Generate quiet output"
		Spec::Rake::SpecTask.new( :quiet ) do |task|
			task.spec_files = SPEC_FILES
			task.spec_opts = ['-f', 'p', '-D']
		end

		desc "Generate HTML output for a spec run"
		Spec::Rake::SpecTask.new( :html ) do |task|
			task.spec_files = SPEC_FILES
			task.spec_opts = ['-f','h', '-D']
		end

		desc "Generate plain-text output for a CruiseControl.rb build"
		Spec::Rake::SpecTask.new( :text ) do |task|
			task.spec_files = SPEC_FILES
			task.spec_opts = ['-f','p']
		end
	end
rescue LoadError => err
	task :no_rspec do
		$stderr.puts "Specification tasks not defined: %s" % [ err.message ]
	end

	task :spec => :no_rspec
	namespace :spec do
		task :autotest => :no_rspec
		task :quiet => :no_rspec
		task :html => :no_rspec
		task :text => :no_rspec
	end
end


### Test::Unit tests
begin
	require 'rake/testtask'
	
	Rake::TestTask.new( :unittests ) do |task|
		task.libs += [LIBDIR]
		task.test_files = TEST_FILES
		task.verbose = true
	end

rescue LoadError => err
	task :no_test do
		$stderr.puts "Test tasks not defined: %s" % [ err.message ]
	end

	task :unittests => :no_rspec
end

	
### RCov (via RSpec) tasks
begin
	gem 'rcov'
	gem 'rspec', '>= 1.1.3'

	COVERAGE_TARGETDIR = BASEDIR + 'coverage'

	### Task: coverage (via RCov)
	### Task: rcov
	desc "Build test coverage reports"
	unless SPEC_FILES.empty?
		Spec::Rake::SpecTask.new( :coverage ) do |task|
			task.spec_files = SPEC_FILES
			task.libs += [LIBDIR]
			task.spec_opts = ['-f', 'p', '-b']
			task.rcov_opts = RCOV_OPTS
			task.rcov = true
		end
	end
	unless TEST_FILES.empty?
		require 'rcov/rcovtask'

		Rcov::RcovTask.new do |task|
			task.libs += [LIBDIR]
			task.test_files = TEST_FILES
			task.verbose = true
			task.rcov_opts = RCOV_OPTS
		end
	end


	task :rcov => [:coverage] do; end

	### Other coverage tasks
	namespace :coverage do
		desc "Generate a detailed text coverage report"
		Spec::Rake::SpecTask.new( :text ) do |task|
			task.spec_files = SPEC_FILES
			task.rcov_opts = RCOV_OPTS + ['--text-report']
			task.rcov = true
		end

		desc "Show differences in coverage from last run"
		Spec::Rake::SpecTask.new( :diff ) do |task|
			task.spec_files = SPEC_FILES
			task.rcov_opts = ['--text-coverage-diff']
			task.rcov = true
		end

		### Task: verify coverage
		desc "Build coverage statistics"
		VerifyTask.new( :verify => :rcov ) do |task|
			task.threshold = COVERAGE_MINIMUM
		end

		desc "Run RCov in 'spec-only' mode to check coverage from specs"
		Spec::Rake::SpecTask.new( :speconly ) do |task|
			task.spec_files = SPEC_FILES
			task.rcov_opts = ['--exclude', SPEC_EXCLUDES, '--text-report', '--save']
			task.rcov = true
		end
	end

	task :clobber_coverage do
		rmtree( COVERAGE_TARGETDIR )
	end

rescue LoadError => err
	task :no_rcov do
		$stderr.puts "Coverage tasks not defined: RSpec+RCov tasklib not available: %s" %
		[ err.message ]
	end

	task :coverage => :no_rcov
	task :clobber_coverage
	task :rcov => :no_rcov
	namespace :coverage do
		task :text => :no_rcov
		task :diff => :no_rcov
	end
	task :verify => :no_rcov
end


