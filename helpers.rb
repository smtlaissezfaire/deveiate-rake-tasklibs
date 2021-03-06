#####################################################################
###	G L O B A L   H E L P E R   F U N C T I O N S
#####################################################################

require 'pathname'
require 'readline'

# Set some ANSI escape code constants (Shamelessly stolen from Perl's
# Term::ANSIColor by Russ Allbery <rra@stanford.edu> and Zenin <zenin@best.com>
ANSI_ATTRIBUTES = {
	'clear'      => 0,
	'reset'      => 0,
	'bold'       => 1,
	'dark'       => 2,
	'underline'  => 4,
	'underscore' => 4,
	'blink'      => 5,
	'reverse'    => 7,
	'concealed'  => 8,

	'black'      => 30,   'on_black'   => 40, 
	'red'        => 31,   'on_red'     => 41, 
	'green'      => 32,   'on_green'   => 42, 
	'yellow'     => 33,   'on_yellow'  => 43, 
	'blue'       => 34,   'on_blue'    => 44, 
	'magenta'    => 35,   'on_magenta' => 45, 
	'cyan'       => 36,   'on_cyan'    => 46, 
	'white'      => 37,   'on_white'   => 47
}


MULTILINE_PROMPT = <<-'EOF'
Enter one or more values for '%s'.
A blank line finishes input.
EOF


CLEAR_TO_EOL       = "\e[K"
CLEAR_CURRENT_LINE = "\e[2K"


### Output a logging message
def log( *msg )
	output = colorize( msg.flatten.join(' '), 'cyan' )
	$deferr.puts( output )
end


### Output a logging message if tracing is on
def trace( *msg )
	return unless $trace
	output = colorize( msg.flatten.join(' '), 'yellow' )
	$deferr.puts( output )
end


### Run the specified command +cmd+ with system(), failing if the execution
### fails.
def run( *cmd )
	cmd.flatten!

	if cmd.length > 1
		trace( cmd.collect {|part| part =~ /\s/ ? part.inspect : part} ) 
	else
		trace( cmd )
	end
	
	if $dryrun
		$deferr.puts "(dry run mode)"
	else
		system( *cmd )
		unless $?.success?
			fail "Command failed: [%s]" % [cmd.join(' ')]
		end
	end
end


### Run a subordinate Rake process with the same options and the specified +targets+.
def rake( *targets )
	opts = ARGV.select {|arg| arg[0,1] == '-' }
	args = opts + targets.map {|t| t.to_s }
	run 'rake', *args
end


### Open a pipe to a process running the given +cmd+ and call the given block with it.
def pipeto( *cmd )
	$DEBUG = true

	cmd.flatten!
	log( "Opening a pipe to: ", cmd.collect {|part| part =~ /\s/ ? part.inspect : part} ) 
	if $dryrun
		$deferr.puts "(dry run mode)"
	else
		open( '|-', 'w+' ) do |io|
		
			# Parent
			if io
				yield( io )

			# Child
			else
				exec( *cmd )
				fail "Command failed: [%s]" % [cmd.join(' ')]
			end
		end
	end
end


### Download the file at +sourceuri+ via HTTP and write it to +targetfile+.
def download( sourceuri, targetfile=nil )
	oldsync = $defout.sync
	$defout.sync = true
	require 'net/http'
	require 'uri'

	targetpath = Pathname.new( targetfile )

	log "Downloading %s to %s" % [sourceuri, targetfile]
	targetpath.open( File::WRONLY|File::TRUNC|File::CREAT, 0644 ) do |ofh|
	
		url = sourceuri.is_a?( URI ) ? sourceuri : URI.parse( sourceuri )
		downloaded = false
		limit = 5
		
		until downloaded or limit.zero?
			Net::HTTP.start( url.host, url.port ) do |http|
				req = Net::HTTP::Get.new( url.path )

				http.request( req ) do |res|
					if res.is_a?( Net::HTTPSuccess )
						log "Downloading..."
						res.read_body do |buf|
							ofh.print( buf )
						end
						downloaded = true
						puts "done."
		
					elsif res.is_a?( Net::HTTPRedirection )
						url = URI.parse( res['location'] )
						log "...following redirection to: %s" % [ url ]
						limit -= 1
						sleep 0.2
						next
				
					else
						res.error!
					end
				end
			end
		end
		
	end
	
	return targetpath
ensure
	$defout.sync = oldsync
end


### Return the fully-qualified path to the specified +program+ in the PATH.
def which( program )
	ENV['PATH'].split(/:/).
		collect {|dir| Pathname.new(dir) + program }.
		find {|path| path.exist? && path.executable? }
end


### Create a string that contains the ANSI codes specified and return it
def ansi_code( *attributes )
	attributes.flatten!
	attributes.collect! {|at| at.to_s }
	# $deferr.puts "Returning ansicode for TERM = %p: %p" %
	# 	[ ENV['TERM'], attributes ]
	return '' unless /(?:vt10[03]|xterm(?:-color)?|linux|screen)/i =~ ENV['TERM']
	attributes = ANSI_ATTRIBUTES.values_at( *attributes ).compact.join(';')

	# $deferr.puts "  attr is: %p" % [attributes]
	if attributes.empty? 
		return ''
	else
		return "\e[%sm" % attributes
	end
end


### Colorize the given +string+ with the specified +attributes+ and return it, handling 
### line-endings, color reset, etc.
def colorize( *args )
	string = ''
	
	if block_given?
		string = yield
	else
		string = args.shift
	end
	
	ending = string[/(\s)$/] || ''
	string = string.rstrip

	return ansi_code( args.flatten ) + string + ansi_code( 'reset' ) + ending
end


### Output the specified <tt>msg</tt> as an ANSI-colored error message
### (white on red).
def error_message( msg, details='' )
	$deferr.puts colorize( 'bold', 'white', 'on_red' ) { msg } + details
end
alias :error :error_message


### Highlight and embed a prompt control character in the given +string+ and return it.
def make_prompt_string( string )
	return CLEAR_CURRENT_LINE + colorize( 'bold', 'green' ) { string + ' ' }
end


### Output the specified <tt>prompt_string</tt> as a prompt (in green) and
### return the user's input with leading and trailing spaces removed.  If a
### test is provided, the prompt will repeat until the test returns true.
### An optional failure message can also be passed in.
def prompt( prompt_string, failure_msg="Try again." ) # :yields: response
	prompt_string.chomp!
	prompt_string << ":" unless /\W$/.match( prompt_string )
	response = nil

	begin
		prompt = make_prompt_string( prompt_string )
		response = Readline.readline( prompt ) || ''
		response.strip!
		if block_given? && ! yield( response ) 
			error_message( failure_msg + "\n\n" )
			response = nil
		end
	end while response.nil?

	return response
end


### Prompt the user with the given <tt>prompt_string</tt> via #prompt,
### substituting the given <tt>default</tt> if the user doesn't input
### anything.  If a test is provided, the prompt will repeat until the test
### returns true.  An optional failure message can also be passed in.
def prompt_with_default( prompt_string, default, failure_msg="Try again." )
	response = nil

	begin
		default ||= '~'
		response = prompt( "%s [%s]" % [ prompt_string, default ] )
		response = default.to_s if !response.nil? && response.empty? 

		trace "Validating reponse %p" % [ response ]

		# the block is a validator.  We need to make sure that the user didn't
		# enter '~', because if they did, it's nil and we should move on.  If
		# they didn't, then call the block.
		if block_given? && response != '~' && ! yield( response )
			error_message( failure_msg + "\n\n" )
			response = nil
		end
	end while response.nil?

	return nil if response == '~'
	return response
end


### Prompt for an array of values
def prompt_for_multiple_values( label, default=nil )
    $stderr.puts( MULTILINE_PROMPT % [label] )
    if default
		$stderr.puts "Enter a single blank line to keep the default:\n  %p" % [ default ]
	end

    results = []
    result = nil
    
    begin
        result = Readline.readline( make_prompt_string("> ") )
		if result.nil? || result.empty?
			results << default if default && results.empty?
		else
        	results << result 
		end
    end until result.nil? || result.empty?
    
    return results.flatten
end


### Turn echo and masking of input on/off. 
def noecho( masked=false )
	require 'termios'

	rval = nil
	term = Termios.getattr( $stdin )

	begin
		newt = term.dup
		newt.c_lflag &= ~Termios::ECHO
		newt.c_lflag &= ~Termios::ICANON if masked

		Termios.tcsetattr( $stdin, Termios::TCSANOW, newt )

		rval = yield
	ensure
		Termios.tcsetattr( $stdin, Termios::TCSANOW, term )
	end
	
	return rval
end


### Prompt the user for her password, turning off echo if the 'termios' module is
### available.
def prompt_for_password( prompt="Password: " )
	return noecho( true ) do
		$stderr.print( prompt )
		($stdin.gets || '').chomp
	end
end


### Display a description of a potentially-dangerous task, and prompt
### for confirmation. If the user answers with anything that begins
### with 'y', yield to the block. If +abort_on_decline+ is +true+,
### any non-'y' answer will fail with an error message.
def ask_for_confirmation( description, abort_on_decline=true )
	puts description

	answer = prompt_with_default( "Continue?", 'n' ) do |input|
		input =~ /^[yn]/i
	end

	if answer =~ /^y/i
		return yield
	elsif abort_on_decline
		error "Aborted."
		fail
	end

	return false
end
alias :prompt_for_confirmation :ask_for_confirmation


### Search line-by-line in the specified +file+ for the given +regexp+, returning the
### first match, or nil if no match was found. If the +regexp+ has any capture groups,
### those will be returned in an Array, else the whole matching line is returned.
def find_pattern_in_file( regexp, file )
	rval = nil
	
	File.open( file, 'r' ).each do |line|
		if (( match = regexp.match(line) ))
			rval = match.captures.empty? ? match[0] : match.captures
			break
		end
	end

	return rval
end


### Get a list of the file or files to run rspec on.
def rspec_files
	if ENV['class']
		classname = ENV['class']
		spec_file = SPECSDIR + "#{classname}_spec.rb"
		raise "Can't find the spec file for the class '#{classname}'" unless spec_file.exist?
		return [ spec_file ]
	else
		return SPEC_FILES
	end
end


### Invoke the user's editor on the given +filename+ and return the exit code
### from doing so.
def edit( filename )
	editor = ENV['EDITOR'] || ENV['VISUAL'] || DEFAULT_EDITOR
	system editor, filename
	unless $?.success?
		fail "Editor exited uncleanly."
	end
end


### Extract all the non Rake-target arguments from ARGV and return them.
def get_target_args
	args = ARGV.reject {|arg| Rake::Task.task_defined?(arg) }
	return args
end



