# 
# Packaging Rake Tasks
# 
# 

require 'rake/packagetask'
require 'rake/gempackagetask'

### Task: gem
### Task: package
Rake::PackageTask.new( PKG_NAME, PKG_VERSION ) do |task|
  	task.need_tar_gz   = true
	task.need_tar_bz2  = true
	task.need_zip      = true
	task.package_dir   = PKGDIR.to_s
  	task.package_files = RELEASE_FILES.
		collect {|f| f.relative_path_from(BASEDIR).to_s }
end
task :package => [:gem]


### Task: gem
gempath = PKGDIR + GEM_FILE_NAME

desc "Build a RubyGem package (#{GEM_FILE_NAME})"
task :gem => gempath.to_s
file gempath.to_s => [PKGDIR.to_s] + GEMSPEC.files do
	when_writing( "Creating GEM" ) do
		Gem::Builder.new( GEMSPEC ).build
		verbose( true ) do
			mv GEM_FILE_NAME, gempath
		end
	end
end

### Task: install
desc "Install <%= project_name %> as a conventional library"
task :install do
	log "Installing <%= project_name %> as a conventional library"
	sitelib = Pathname.new( CONFIG['sitelibdir'] )
	sitearch = Pathname.new( CONFIG['sitearchdir'] )
	Dir.chdir( LIBDIR ) do
		LIB_FILES.each do |libfile|
			relpath = libfile.relative_path_from( LIBDIR )
			target = sitelib + relpath
			FileUtils.mkpath target.dirname,
				:mode => 0755, :verbose => true, :noop => $dryrun unless target.dirname.directory?
			FileUtils.install relpath, target,
				:mode => 0644, :verbose => true, :noop => $dryrun
		end
	end
	if EXTDIR.exist?
		Dir.chdir( EXTDIR ) do
			Pathname.glob( EXTDIR + Config::CONFIG['DLEXT'] ) do |dl|
				target = sitearch + dl.basename
				FileUtils.install dl, target, 
					:mode => 0755, :verbose => true, :noop => $dryrun
			end
		end
	end
end



### Task: install_gem
desc "Install <%= project_name %> from a locally-built gem"
task :install_gem => [:package] do
	$stderr.puts 
	installer = Gem::Installer.new( %{pkg/#{PKG_FILE_NAME}.gem} )
	installer.install
end

### Task: uninstall_gem
desc "Install the <%= project_name %> gem"
task :uninstall_gem => [:clean] do
	uninstaller = Gem::Uninstaller.new( PKG_FILE_NAME )
	uninstaller.uninstall
end



