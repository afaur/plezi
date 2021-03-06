
module Plezi

	# File and Object Caching for Plezi
	#
	# Be aware that the cache is local, per process. It's possible to limit file caching by limiting the supported_types in Plezi::Cache::CACHABLE.
	#
	# Template rendering engines are always cached.
	module Cache
		# contains the cached data, in the format: CACHE_STORE["filename"] = CacheObject
		CACHE_STORE = {}
		CACHE_LOCK = Mutex.new
		CACHABLE = (%w{cache object slim haml css map js html scss sass coffee txt xml json yaml rb}).to_set

		@cache_to_disk = true

		# this class holds cached objects (data and modification times)
		class CacheObject
			# Cached attributes
			attr_accessor :data, :mtime

			# initialize a Cached object
			def initialize d = nil, t = Time.now
				@data = d
				@mtime = t
			end
		end

		# load the file from the cache (if exists) or the file system (if it doesn't)
		def load_file filename
			cached?(filename) ? get_cached(filename) : reload_file(filename)
		end
		# review a file's modification time
		def file_mtime filename
			return CACHE_STORE[filename].mtime if cached?(filename)
			File.mtime(filename)
		end

		# force a file onto the cache (only if it is cachable - otherwise will load the file but will not cache it).
		def reload_file filename
			if CACHABLE.include? filename.match(/\.([^\.]+)$/)[1]
				return cache_data filename, IO.binread(filename), File.mtime(filename)
			else
				return IO.binread(filename)
			end
		end
		# places data into the cache, and attempts to save the data to a file name.
		def save_file filename, data, save_to_disk = false
			cache_data filename, data if CACHABLE.include? filename.match(/\.([^\.]+)$/)[1]
			begin
				IO.binwrite filename, data if save_to_disk
			rescue Exception => e
				Plezi.warn("File couldn't be written (#{filename}) - file system error?")
			end
			data
		end

		# places data into the cache, under an identifier ( file name ).
		def cache_data filename, data, mtime = Time.now
			CACHE_LOCK.synchronize { CACHE_STORE[filename] = CacheObject.new( data, mtime )  }
			data
		end

		# Get data from the cache. will throw an exception if there is no data in the cache.
		def get_cached filename
			CACHE_STORE[filename].data # if CACHE_STORE[filename]
		end

		# Remove data from the cache, if it exists.
		def clear_cached filename
			CACHE_LOCK.synchronize { CACHE_STORE.delete filename } # if CACHE_STORE[filename]
		end

		# clears all cached data.
		def clear_cache! filename
			CACHE_LOCK.synchronize { CACHE_STORE.clear } # if CACHE_STORE[filename]
		end

		# returns true if the filename is cached.
		def cached? filename
			!CACHE_STORE[filename].nil?
		end

		# returns true if the file exists on disk or in the cache.
		def file_exists? filename
			(CACHE_STORE[filename] || File.exists?(filename)) ? true : false
		end

		# returns true if the file has been update since data was last cached.
		def cache_needs_update? filename
			return true if CACHE_STORE[filename].nil? || CACHE_STORE[filename].mtime < File.mtime(filename)
			false
		end
	end

	public

	extend Plezi::Cache
end
