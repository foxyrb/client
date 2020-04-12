# frozen_string_literal: true

module Foxy
  module Client
    class Utils
      class << self
        def try_first(object, meth, *args, &block)
          return nil if object.nil?

          if meth.is_a?(Array)
            [meth, *args].each do |m, *a|
              return object.public_send(m, *a, &block) if object.respond_to?(m)
            end
            nil
          else
            object.public_send(meth, *args, &block) if object.respond_to?(meth)
          end
        end

        def deep_merge(hash, second)
          merger = proc { |_, v1, v2| v1.is_a?(Hash) && v2.is_a?(Hash) ? v1.merge(v2, &merger) : v2 }
          hash.merge(second, &merger)
        end

        def recursive_hash(hash)
          hash.tap { hash.default_proc = proc { |h, k| h[k] = Hash.new(&h.default_proc) } }
        end

        def deep_clone(elem)
          if elem.respond_to?(:deep_clone)
            elem.deep_clone
          elsif elem.is_a?(Hash)
            elem.clone.tap do |new_obj|
              new_obj.each do |key, val|
                new_obj[key] = deep_clone(val)
              end
            end
          elsif elem.is_a?(Array)
            elem.map { |val| deep_clone(val) }
          else
            elem
          end
        end

        def user_agent(app: "Foxy", version: "0.0")
          login = Etc.getlogin
          hostname = Socket.gethostname
          pid = Process.pid

          app = "#{app}/#{version} (#{hostname}; #{login}; #{pid})"
          ruby = "#{RUBY_ENGINE}/#{RUBY_VERSION} (#{RUBY_PATCHLEVEL}; #{RUBY_PLATFORM})"

          "#{app} #{ruby}"
        end
      end
    end
  end
end
