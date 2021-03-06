module Plezi
	module Base

		# Sends common basic HTTP responses.
		module HTTPSender
			module_function

			######
			## basic responses
			## (error codes and static files)

			# sends a response for an error code, rendering the relevent file (if exists).
			def send_by_code request, response, code, headers = {}
				begin
					base_code_path = request.io.params[:templates] || File.expand_path('.')
					if defined?(::Slim) && Plezi.file_exists?(fn = File.join(base_code_path, "#{code}.html.slim"))
						Plezi.cache_data fn, Slim::Template.new( fn ) unless Plezi.cached? fn
						return send_raw_data request, response, Plezi.get_cached( fn ).render( self, request: request ), 'text/html', code, headers
					elsif defined?(::Haml) && Plezi.file_exists?(fn = File.join(base_code_path, "#{code}.html.haml"))
						Plezi.cache_data fn, Haml::Engine.new( IO.binread( fn ) ) unless Plezi.cached? fn
						return send_raw_data request, response, Plezi.get_cached( File.join(base_code_path, "#{code}.html.haml") ).render( self ), 'text/html', code, headers
					elsif defined?(::ERB) && Plezi.file_exists?(fn = File.join(base_code_path, "#{code}.html.erb"))
						return send_raw_data request, response, ERB.new( Plezi.load_file( fn ) ).result(binding), 'text/html', code, headers
					elsif Plezi.file_exists?(fn = File.join(base_code_path, "#{code}.html"))
						return send_file(request, response, fn, code, headers)
					end
					return true if send_raw_data(request, response, response.class::STATUS_CODES[code], 'text/plain', code, headers)
				rescue Exception => e
					Plezi.error e
				end
				false
			end

			# attempts to send a static file by the request path (using `send_file` and `send_raw_data`).
			#
			# returns true if data was sent.
			def send_static_file request, response
				root = request.io[:params][:public]
				return false unless root
				file_requested = request[:path].to_s.split('/')
				unless file_requested.include? '..'
					file_requested.shift
					file_requested = File.join(root, *file_requested)
					return true if send_file request, response, file_requested
					return send_file request, response, File.join(file_requested, request.io[:params][:index_file])
				end
				false
			end

			# sends a file/cacheed data if it exists. otherwise returns false.
			def send_file request, response, filename, status_code = 200, headers = {}
				if Plezi.file_exists?(filename) && !::File.directory?(filename)
					return send_raw_data request, response, Plezi.load_file(filename), MimeTypeHelper::MIME_DICTIONARY[::File.extname(filename)], status_code, headers
				end
				return false
			end
			# sends raw data through the connection. always returns true (data send).
			def send_raw_data request, response, data, mime, status_code = 200, headers = {}
				headers.each {|k, v| response[k] = v}
				response.status = status_code
				response['content-type'] = mime
				response['cache-control'] ||= 'public, max-age=86400'					
				response << data
				response['content-length'] = data.bytesize
				true
			end##########


		end

	end
end
