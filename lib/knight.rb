require 'getoptlong'
require 'net/http'
require 'open-uri'
require 'cgi'
require 'thread'
require 'rbconfig' 
require 'resolv'
require 'resolv-replace' 
require 'open-uri'
require 'digest/md5'
require 'openssl' 
require 'pp'

require_relative 'knight/version.rb'
require_relative 'knight/banner.rb'
require_relative 'knight/scan.rb'
require_relative 'knight/parser.rb'
require_relative 'knight/redirect.rb'
require_relative 'gems.rb'
require_relative 'helper.rb'
require_relative 'target.rb'
require_relative 'plugins.rb'
require_relative 'plugin_support.rb'
require_relative 'logging.rb'
require_relative 'colour.rb'
require_relative 'version_class.rb'
require_relative 'http-status.rb'
require_relative 'extend-http.rb'

Dir["#{File.expand_path(File.dirname(__FILE__))}/logging/*.rb"].each {|file| require file }

$WWDEBUG = false 
$verbose = 0 
$use_colour = 'auto'
$QUIET = false
$NO_ERRORS = false
$LOG_ERRORS = nil
$PLUGIN_TIMES = Hash.new(0)

$USER_AGENT = "Knight/#{Knight::VERSION}"
$AGGRESSION = 1
$FOLLOW_REDIRECT = 'always'
$USE_PROXY = false
$PROXY_HOST = nil
$PROXY_PORT = 8080
$PROXY_USER = nil
$PROXY_PASS = nil
$HTTP_OPEN_TIMEOUT = 15
$HTTP_READ_TIMEOUT = 30
$WAIT = nil
$CUSTOM_HEADERS = {}
$BASIC_AUTH_USER = nil
$BASIC_AUTH_PASS = nil

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new(2.0)
  raise('Unsupported version of Ruby to run this tool. Knight requires Ruby 2.0 or later.')
end

HTTP_Status.initialize

PLUGIN_DIRS = []

$load_path_plugins = [
	File.expand_path('../', __dir__),
	"/usr/share/knight" 
]

$load_path_plugins.each do |dir|
	if Dir.exist?(File.expand_path("plugins", dir)) and Dir.exist?(File.expand_path("my-plugins", dir))
		PLUGIN_DIRS << File.expand_path("plugins", dir)
		PLUGIN_DIRS << File.expand_path("my-plugins", dir)
		break
	end
end