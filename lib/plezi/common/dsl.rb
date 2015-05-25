
module Plezi

	# holds methods that are called by the DSL.
	#
	# this isn't part of the public API.
	module DSL
		module_function

		# this module contains the methods that are used as a DSL and sets up easy access to the Plezi framework.
		#
		# use the`listen`, `host` and `route` functions rather then accessing this object.
		#
		@servers = {}
		@active_router = nil

		# adds a route to the last server created
		def route(path, controller = nil, &block)
			@active_router.add_route path, controller, &block
		end


		# adds a shared route to all existing services and hosts.
		def shared_route(path, controller = nil, &block)
			@listeners.values.each {|p| (defined?(PLEZI_ON_RACK) ? p[:handler] : p.params[:handler]).add_shared_route path, controller, &block }
		end

		# adds a host to the last server created
		#
		# accepts the same parameter(s) as the `listen` command (see Plezi.add_service), except :protocol and :handler are ignored:
		# alias:: a String or an Array of Strings which represent alternative host names (i.e. `alias: ["admin.google.com", "admin.gmail.com"]`).
		def host(host_name, params)
			@active_router.add_host host_name, params
		end

		# Rack application model support

		# Plezi dresses up for Rack - this is a watered down version missing some features (such as flash and WebSockets).
		# a full featured Plezi app, with WebSockets, requires the use of the Plezi server
		# (the built-in server)
		def call env
			raise "No Plezi Services" unless @listeners && @listeners.any?

			# re-encode to utf-8, as it's all BINARY encoding at first
			env['rack.input'].rewind
			env['rack.input'] = StringIO.new env['rack.input'].read.encode('utf-8', 'binary', invalid: :replace, undef: :replace, replace: '')		 	
			env.each do |k, v|
				if k.to_s.match /^[A-Z]/
					if v.is_a?(String) && !v.frozen?
						v.force_encoding('binary').encode!('utf-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless v.force_encoding('utf-8').valid_encoding?
					end
				end
			end
			# re-key params
			# new_params = {}
			# env[:params].each {|k,v| HTTP.add_param_to_hash k, v, new_params}
			# env[:params] = new_params

			# make hashes magical
			make_hash_accept_symbols(env)

			# use Plezi Cookies
			env['rack.request.cookie_string'] = env['HTTP_COOKIE']
			env['rack.request.cookie_hash'] = Plezi::Cookies.new.update(env['rack.request.cookie_hash'] || {})

			# chomp path
			env['PATH_INFO'].chomp! '/'

			# get response
			response = @listeners.first[1][:handler].call env

			return response if response.is_a?(Array)

			return [404, {}, ['not found']] if response === true

			response.prep_rack
			headers = response.headers
			# headers.delete 'transfer-encoding'
			# headers.delete 'connection'
			# set cookie headers
			unless response.cookies.empty?
				headers['Set-Cookie'] = []
				response.cookies.each {|k,v| headers['Set-Cookie'] << ("#{k.to_s}=#{v.to_s}")}
			end
			[response.status, headers, response.body]
		end

		# tweeks a hash object to read both :symbols and strings (similar to Rails but without).
		def make_hash_accept_symbols hash
			@magic_hash_proc ||= Proc.new do |hs,k|
				if k.is_a?(Symbol) && hs.has_key?( k.to_s)
					hs[k.to_s]
				elsif k.is_a?(String) && hs.has_key?( k.to_sym)
					hs[k.to_sym]
				elsif k.is_a?(Numeric) && hs.has_key?(k.to_s.to_sym)
					hs[k.to_s.to_sym]
				end
			end
			hash.default_proc = @magic_hash_proc
			hash.values.each do |v|
				if v.is_a?(Hash)
					make_hash_accept_symbols v
				end
			end
		end

	end
end

Encoding.default_internal = 'utf-8'
Encoding.default_external = 'utf-8'

# PL is a shortcut for the Plezi module, so that `PL == Plezi`.
PL = Plezi

# shortcut for Plezi.listen.
#
def listen(params = {})
	Plezi::DSL.listen params
end

# adds a virtul host to the current service (the last `listen` call) or switches to an existing host within the active service.
#
# accepts:
# host_name: a String with the full host name (i.e. "www.google.com" / "mail.google.com")
# params:: any of the parameters accepted by the `listen` command, except `protocol`, `handler`, and `ssl` parameters.
def host(host_name = false, params = {})
	Plezi::DSL.host host_name, params
end

# adds a route to the last server object
#
# path:: the path for the route
# controller:: The controller class which will accept the route.
#
# `path` parameters has a few options:
#
# * `path` can be a Regexp object, forcing the all the logic into controller (typically using the before method).
#
# * simple String paths are assumed to be basic RESTful paths:
#
#     route "/users", Controller => route "/users/(:id)", Controller
#
# * routes can define their own parameters, for their own logic:
#
#     route "/path/:required_paramater/:required_paramater{with_format}/(:optional_paramater)/(:optional){with_format}"
#
# * routes can define optional or required routes with regular expressions in them:
#
#     route "(:locale){en|ru}/path"
#
# * routes which use the special '/' charecter within a parameter's format, must escape this charecter using the '\' charecter. **Notice the single quotes** in the following example:
#
#     route '(:math){[\d\+\-\*\^\%\.\/]}'
#
#   * or, with double quotes:
#
#     route "(:math){[\\d\\+\\-\\*\\^\\%\\.\\/]}"
#
# magic routes make for difficult debugging - the smarter the routes, the more difficult the debugging.
# use with care and avoid complex routes when possible. RESTful routes are recommended when possible.
# json serving apps are advised to use required parameters, empty sections indicating missing required parameters (i.e. /path///foo/bar///).
#
def route(path, controller = nil, &block)
	Plezi::DSL.route(path, controller, &block)
end

# adds a route to the all the existing servers and hosts.
#
# accepts same options as route.
def shared_route(path, controller = nil, &block)
	Plezi::DSL.shared_route(path, controller, &block)
end

# defines a method with a special name, such as "humens.txt".
#
# this could be used in controller classes, to define special routes which might defy
# normal Ruby naming conventions, such as "/welcome-home", "/play!", etc'
#
# could also be used to define methods with special formatting, such as "humans.txt",
# until a more refined way to deal with formatting will be implemented.
def def_special_method name, obj=self, &block
	obj.instance_eval { define_method name.to_s.to_sym, &block }
end



# finishes setup of the servers and starts them up. This will hange the proceess.
#
# this method is called automatically by the Plezi framework.
#
# it is recommended that you DO NOT CALL this method.
# if any post shut-down actions need to be performed, use Plezi.on_shutdown instead.
def start_services
	return 0 if ( defined?(NO_PLEZI_AUTO_START) || defined?(BUILDING_PLEZI_TEMPLATE) || defined?(PLEZI_ON_RACK) )
	Object.const_set "NO_PLEZI_AUTO_START", true
	undef listen
	undef host
	undef route
	undef shared_route
	undef start_services
	Plezi::DSL.start_services
end

# restarts the Plezi app with the same arguments as when it was started.
#
# EXPERIMENTAL
def restart_plezi_app
	exec "/usr/bin/env ruby #{$PL_SCRIPT} #{$PL_ARGV.join ' '}"
end

# sets to start the services once dsl script is finished loading.
at_exit { start_services } unless ( defined?(NO_PLEZI_AUTO_START) || defined?(BUILDING_PLEZI_TEMPLATE) || defined?(PLEZI_ON_RACK) )

# sets information to be used when restarting
$PL_SCRIPT = $0
$PL_ARGV = $*.dup
# $0="Plezi (Ruby)"
