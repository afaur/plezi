module Plezi
	module Base

		# the methods defined in this module will be injected into the Controller's Core class (inherited from the controller).
		module ControllerCore
			def self.included base
				base.send :include, Plezi::Base::WSObject
				base.send :include, InstanceMethods
				base.extend ClassMethods
			end

			module InstanceMethods
				public

				def initialize request, response
					@request = request
					@params = request.params
					@flash = response.flash
					@host_params = request.io[:params]
					@response = response
					@cookies = request.cookies
					# # \@response["content-type"] ||= ::Plezi.default_content_type
					super()
				end


				# WebSockets.
				#
				# this method handles the protocol and handler transition between the HTTP connection
				# (with a protocol instance of HTTPProtocol and a handler instance of HTTPRouter)
				# and the WebSockets connection
				# (with a protocol instance of WSProtocol and an instance of the Controller class set as a handler)
				def pre_connect
					# make sure this is a websocket controller
					return false unless self.class.has_super_method?(:on_message)
					# call the controller's original method, if exists, and check connection.
					return false if (defined?(super) && !super)
					# finish if the response was sent
					return false if response.headers_sent?
					# make sure that the session object is available for websocket connections
					response.session
					# complete handshake
					return self
				end
				# handles websocket opening.
				def on_open ws
					# set broadcasts and return true
					@response = ws
					ws.autoping Plezi::Settings.autoping if Plezi::Settings.autoping
					# create the redis connection (in case this in the first instance of this class)
					Plezi.redis
					super() if defined?(super)
				end
				# handles websocket messages.
				def on_message ws
					super(ws.data) if defined?(super)
				end
				# handles websocket being closed.
				def on_close ws
					super() if defined? super
				end

				# Inner Routing
				#
				#
				def _route_path_to_methods_and_set_the_response_
					#run :before filter
					return false if self.class.has_method?(:before) && self.before == false 
					#check request is valid and call requested method
					ret = requested_method
					return false unless ret
					ret = self.method(ret).call
					return false unless ret
					#run :after filter
					return false if self.class.has_method?(:after) && self.after == false
					# review returned type for adding String to response
					return ret
				end

			end

			module ClassMethods
			end
		end
	end
end
