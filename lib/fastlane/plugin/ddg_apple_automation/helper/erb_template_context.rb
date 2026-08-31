module Fastlane
  module Helper
    # An isolated scope for ERB template rendering.
    #
    # `ERB#result_with_hash` evaluates a template in a copy of `TOPLEVEL_BINDING`, so a
    # `defined?(foo)` guard in a template can see top-level local variables of the process
    # that started Ruby. Some Ruby wrappers set such variables (RVM's `ruby_executable_hooks`
    # sets `title`), which makes an optional template variable resolve to an unrelated value
    # instead of falling back to its default. A template rendered against this context can
    # only see the arguments that were supplied to it.
    class ErbTemplateContext
      def initialize(args)
        args.each do |key, value|
          define_singleton_method(key) { value }
        end
      end

      def template_binding
        binding
      end
    end
  end
end
