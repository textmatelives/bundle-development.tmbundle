#!/usr/bin/env ruby -wEutf-8
# The two .tmCommand launchers must load their implementation through
# TM_BUNDLE_SUPPORT, which TextMate points at the running bundle's Support
# directory wherever the bundle is installed (managed, user, or checkout).
# Each launcher is executed with TM_BUNDLE_SUPPORT aimed at a stub Support
# tree; the stub is only reachable through that variable.
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

$failures = 0

def check(label)
	yield
rescue => e
	puts "FAIL #{label}: #{e.class}: #{e.message}"
	$failures += 1
end

def assert_equal(want, got)
	raise "want #{want.inspect}, got #{got.inspect}" unless want == got
end

COMMANDS = File.expand_path('../../Commands', __dir__)

def command_script(name)
	json = IO.popen(['plutil', '-convert', 'json', '-o', '-', File.join(COMMANDS, name)], &:read)
	raise "could not read #{name}" unless $?.success?
	JSON.parse(json)['command']
end

# Runs a launcher with TM_BUNDLE_SUPPORT pointed at a Support tree holding
# the given stub lib file. Returns [output, success?].
def run_launcher(script, lib_name, stub)
	Dir.mktmpdir do |dir|
		support = File.join(dir, 'Support')
		script_path = File.join(dir, 'launcher.rb')
		File.write(script_path, script)
		FileUtils.mkdir_p(File.join(support, 'lib'))
		File.write(File.join(support, 'lib', lib_name), stub)
		out, status = Open3.capture2(
			{ 'TM_BUNDLE_SUPPORT' => support },
			RbConfig.ruby, '-wEutf-8', script_path, :stdin_data => '')
		return [out, status.success?]
	end
end

check('Show theme colors loads through TM_BUNDLE_SUPPORT') do
	script = command_script('Show theme colors.tmCommand')
	out, ok = run_launcher(script, 'theme_colors.rb', <<~RUBY)
		module ThemeColors
			def self.show
				puts 'theme-stub-ok'
			end
		end
	RUBY
	assert_equal(true, ok)
	assert_equal(true, out.include?('theme-stub-ok'))
end

check('Edit Color loads through TM_BUNDLE_SUPPORT') do
	script = command_script('Edit Color.tmCommand')
	out, ok = run_launcher(script, 'edit_color.rb', <<~RUBY)
		module EditColor
			def self.run
				print 'edit-stub-ok'
			end
		end
	RUBY
	assert_equal(true, ok)
	assert_equal(true, out.include?('edit-stub-ok'))
end

if $failures.zero?
	puts 'ok'
else
	puts "#{ $failures } failed"
	exit 1
end
