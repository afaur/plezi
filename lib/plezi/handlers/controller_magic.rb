module Plezi

	# the methods defined in this module will be injected into the Controller class passed to
	# Plezi (using the `route` or `shared_route` commands), and will be available
	# for the controller to use within it's methods.
	#
	# for some reason, the documentation ignores the following additional attributes, which are listed here:
	#
	# request:: the HTTPRequest object containing all the data from the HTTP request. If a WebSocket connection was established, the `request` object will continue to contain the HTTP request establishing the connection (cookies, parameters sent and other information).
	# params:: any parameters sent with the request (short-cut for `request.params`), will contain any GET or POST form data sent (including file upload and JSON format support).
	# cookies:: a cookie-jar to get and set cookies (set: `cookie\[:name] = data` or get: `cookie\[:name]`). Cookies and some other data must be set BEFORE the response's headers are sent.
	# flash:: a temporary cookie-jar, good for one request. this is a short-cut for the `response.flash` which handles this magical cookie style.
	# response:: the HTTPResponse **OR** the WSResponse object that formats the response and sends it. use `response << data`. This object can be used to send partial data (such as headers, or partial html content) in blocking mode as well as sending data in the default non-blocking mode.
	# host_params:: a copy of the parameters used to create the host and service which accepted the request and created this instance of the controller class.
	#
	# For Controller Class menthods, please read the documentation about {Plezi::ControllerMagic::ClassMethods}.
	#
	# For Controller Instance methods, please read the documentation about {Plezi::ControllerMagic::InstanceMethods}.
	#
	# {include: Plezi::ControllerMagic::InstanceMethods}
	# 
	module ControllerMagic
		def self.included base
			base.send :include, InstanceMethods
			base.extend ClassMethods
		end

		module InstanceMethods

			public

			# the request object, type HTTPRequest.
			attr_reader :request

			# the :params variable contains all the parameters set by the request (/path?locale=he  => params ["locale"] == "he").
			attr_reader :params

			# A cookie-jar to get and set cookies (set: `cookie [:name] = data` or get: `cookie [ :name ]`).
			#
			# Cookies and some other data must be set BEFORE the response's headers are sent.
			attr_reader :cookies

			# Session data can be stored here (session data will be stored on the Redis server, if Redis is available).
			#
			# The first time this method is called, the session object will be created. The session object must be created BEFORE the headers are set , if it is to be used.
			#
			# Sessions are not automatically created, because they require more resources. The one exception is the Websocket connection that will force a session object into existence, as it's very common to use session data in Websocket connections and the extra connection time is less relevant for a long term connection.
			def session
				response.session
			end

			# the HTTPResponse **OR** the WSResponse object that formats the response and sends it. use `response << data`. This object can be used to send partial data (such as headers, or partial html content) in blocking mode as well as sending data in the default non-blocking mode.
			attr_reader :response

			# the :flash is a little bit of a magic hash that sets and reads temporary cookies.
			# these cookies will live for one successful request to a Controller and will then be removed.
			attr_reader :flash

			# the parameters used to create the host (the parameters passed to the `listen` / `add_service` call).
			attr_reader :host_params

			# this method does two things.
			#
			# 1. sets redirection headers for the response.
			# 2. sets the `flash` object (short-time cookies) with all the values passed except the :status value.
			#
			# use:
			#      redirect_to 'http://google.com', notice: "foo", status: 302
			#      # => redirects to 'http://google.com' with status 302 and adds notice: "foo" to the flash
			# or simply:
			#      redirect_to 'http://google.com'
			#      # => redirects to 'http://google.com' with status 302 (default status)
			#
			# if the url is a symbol, the method will try to format it into a correct url, replacing any
			# underscores ('_') with a backslash ('/').
			#
			# if the url is an empty string, the method will try to format it into a correct url
			# representing the index of the application (http://server/)
			#
			def redirect_to url, options = {}
				return super *[] if defined? super
				raise 'Cannot redirect once a Websocket connection was established.' if response.is_a?(::GRHttp::WSEvent)
				raise 'Cannot redirect after headers were sent.' if response.headers_sent?
				url = "#{request.base_url}/#{url.to_s.gsub('_', '/')}" if url.is_a?(Symbol) || ( url.is_a?(String) && url.empty? ) || url.nil?
				# redirect
				response.status = options.delete(:status) || 302
				response['Location'] = url
				response['content-length'] ||= 0
				flash.update options
				true
			end

			# Returns the RELATIVE url for methods in THIS controller (i.e.: "/path_to_controller/restful/params?non=restful&params=foo")
			#
			# accepts one parameter:
			# dest:: a destination object, either a Hash, a Symbol, a Numerical or a String.
			#
			# If :dest is a Numerical, a Symbol or a String, it should signify the id of an object or the name of the method this controller should respond to.
			#
			# If :dest is a Hash, it should contain all the relevant parameters the url should set (i.e. `url_for id: :new, name: "Jhon Doe"`)
			#
			# If :dest is false (or nil), the String returned will be the url to the index.
			#
			# * If you use the same controller in different routes, the first route will dictate the returned url's structure (cause by route priority).
			#
			# * Not all controllers support this method. Regexp controller paths and multi-path options will throw an exception.
			def url_for dest = nil
				self.class.url_for dest
			end
			# same as #url_for, but returns the full URL (protocol:port:://host/path?params=foo)
			def full_url_for dest
				request.base_url + url_for(dest)
			end

			# Send raw data to be saved as a file or viewed as an attachment. Browser should believe it had recieved a file.
			#
			# this is usful for sending 'attachments' (data to be downloaded) rather then
			# a regular response.
			#
			# this is also usful for offering a file name for the browser to "save as".
			#
			# it accepts:
			# data:: the data to be sent
			# options:: a hash of any of the options listed furtheron.
			#
			# the :symbol=>value options are:
			# type:: the type of the data to be sent. defaults to empty. if :filename is supplied, an attempt to guess will be made.
			# inline:: sets the data to be sent an an inline object (to be viewed rather then downloaded). defaults to false.
			# filename:: sets a filename for the browser to "save as". defaults to empty.
			#
			def send_data data, options = {}
				raise 'Cannot use "send_data" once a Websocket connection was established.' if response.is_a?(::GRHttp::WSEvent)
				# return response.write(data) if response.is_a?(::GRHttp::WSEvent)
				raise 'Cannot use "send_data" after headers were sent' if response.headers_sent?
				Plezi.warn 'HTTP response buffer is cleared by `#send_data`' if response.body && response.body.any? && response.body.clear
				response << data

				# set headers
				content_disposition = options[:inline] ? 'inline' : 'attachment'
				content_disposition << "; filename=#{options[:filename]}" if options[:filename]

				response['content-type'] = (options[:type] ||= MimeTypeHelper::MIME_DICTIONARY[::File.extname(options[:filename])])
				response['content-length'] = data.bytesize rescue true
				response['content-disposition'] = content_disposition
				true
			end

			# Renders a template file (.slim/.erb/.haml) or an html file (.html) to text and attempts to set the response's 'content-type' header (if it's still empty).
			#
			# For example, to render the file `body.html.slim` with the layout `main_layout.html.haml`:
			#   render :body, layout: :main_layout
			#
			# or, for example, to render the file `json.js.slim`
			#   render :json, type: 'js'
			#
			# or, for example, to render the file `template.haml`
			#   render :template, type: ''
			#
			# template:: a Symbol for the template to be used.
			# options:: a Hash for any options such as `:layout` or `locale`.
			# block:: an optional block, in case the template has `yield`, the block will be passed on to the template and it's value will be used inplace of the yield statement.
			#
			# options aceept the following keys:
			# type:: the types for the `:layout' and 'template'. can be any extention, such as `"json"`. defaults to `"html"`.
			# layout:: a layout template that has at least one `yield` statement where the template will be rendered.
			# locale:: the I18n locale for the render. (defaults to params\[:locale]) - only if the I18n gem namespace is defined (`require 'i18n'`).
			#
			# if template is a string, it will assume the string is an
			# absolute path to a template file. it will NOT search for the template but might raise exceptions.
			#
			# if the template is a symbol, the '_' caracters will be used to destinguish sub-folders (NOT a partial template).
			#
			# returns false if the template or layout files cannot be found.
			def render template, options = {}, &block
				# make sure templates are enabled
				return false if host_params[:templates].nil?
				# render layout by recursion, if exists
				(return render(options.delete(:layout), options) { render template, options, &block }) if options[:layout]
				# set up defaults
				options[:type] ||= 'html'
				options[:locale] ||= params[:locale].to_sym if params[:locale]
				#update content-type header
				response['content-type'] ||= (MimeTypeHelper::MIME_DICTIONARY[options[:type]] + "; charset=utf-8".freeze)
				# options[:locals] ||= {}
				I18n.locale = options[:locale] || I18n.default_locale if defined?(I18n) # sets the locale to nil for default behavior even if the locale was set by a previous action - removed: # && options[:locale]
				# find template and create template object
				filename = template.is_a?(String) ? File.join( host_params[:templates].to_s, template) : (File.join( host_params[:templates].to_s, *template.to_s.split('_')) + (options[:type].empty? ? '': ".#{options[:type]}") + '.slim')
				return ( Plezi.cache_needs_update?(filename) ? Plezi.cache_data( filename, ( Slim::Template.new() { IO.binread filename } ) )  : (Plezi.get_cached filename) ).render(self, &block) if defined?(::Slim) && Plezi.file_exists?(filename)
				filename.sub! /\.slim$/, '.haml'
				return ( Plezi.cache_needs_update?(filename) ? Plezi.cache_data( filename, ( Haml::Engine.new( IO.binread(filename) ) ) )  : (Plezi.get_cached filename) ).render(self, &block) if defined?(::Haml) && Plezi.file_exists?(filename)
				filename.sub! /\.haml$/, '.erb'
				return ( Plezi.cache_needs_update?(filename) ? Plezi.cache_data( filename, ( ERB.new( IO.binread(filename) ) ) )  : (Plezi.get_cached filename) ).result(binding, &block) if defined?(::ERB) && Plezi.file_exists?(filename)
				return false
			end

			# returns the initial method called (or about to be called) by the router for the HTTP request.
			#
			# this can be very useful within the before / after filters:
			#   def before
			#     return false unless "check credentials" && [:save, :update, :delete].include?(requested_method)
			#
			# if the controller responds to a WebSockets request (a controller that defines the `on_message` method),
			# the value returned is invalid and will remain 'stuck' on :pre_connect
			# (which is the last method called before the protocol is switched from HTTP to WebSockets).
			def requested_method
				# respond to websocket special case
				return :pre_connect if request.upgrade?
				# respond to save 'new' special case
				return (self.class.has_method?(:save) ? :save : false) if request.request_method.match(/POST|PUT|PATCH/) && (params[:id].nil? || params[:id] == 'new')
				# set DELETE method if simulated
				request.request_method = 'DELETE' if params[:_method].to_s.downcase == 'delete'
				# respond to special :id routing
				return params[:id].to_s.to_sym if params[:id] && self.class.has_exposed_method?(params[:id].to_s.to_sym)
				#review general cases
				case request.request_method
				when 'GET', 'HEAD'
					return (self.class.has_method?(:index) ? :index : false) unless params[:id]
					return (self.class.has_method?(:show) ? :show : false)
				when 'POST', 'PUT', 'PATCH'
					return (self.class.has_method?(:update) ? :update : false)
				when 'DELETE'
					return (self.class.has_method?(:delete) ? :delete : false)
				end
				false
			end
		end

		module ClassMethods
			public

			# This class method behaves the same way as the instance method #url_for. See the instance method's documentation for more details.
			def url_for dest
				get_pl_route.url_for dest				
			end

			# resets the routing cache
			def reset_routing_cache
				@inheritance.each {|sub| sub.reset_routing_cache} if @inheritance
			end

			protected

			# Sets the HTTP route that is the owner of this controller.
			#
			# This is used by the Plezi framework internally and is supplied only for advanced purposes. It is better to avoid using this method. 
			def set_pl_route route
				@pl_http_route = route
			end

			# Gets the HTTP route that is the owner of this controller.
			#
			# This is used to utilize the `url_for` method.
			def get_pl_route
				@pl_http_route
			end

			# a callback that resets the class router whenever a method (a potential route) is added
			def method_added(id)
				reset_routing_cache
			end
			# a callback that resets the class router whenever a method (a potential route) is removed
			def method_removed(id)
				reset_routing_cache
			end
			# a callback that resets the class router whenever a method (a potential route) is undefined (using #undef_method).
			def method_undefined(id)
				reset_routing_cache
			end

			def inherited sub
				(@inheritance ||= [].to_set) << sub
			end
		end

	end
end
