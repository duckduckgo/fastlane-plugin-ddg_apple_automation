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
    #
    # Actions pass the whole environment as template arguments, so the argument names are not
    # under our control. Arguments are therefore defined on the singleton class rather than
    # through `define_singleton_method`, and the binding comes from an unbound instance method,
    # so that an argument named after a method of this class cannot break the rendering.
    class ErbTemplateContext
      def self.binding_for(args)
        context = new
        singleton = context.singleton_class
        args.each do |key, value|
          singleton.send(:define_method, key) { value }
        end
        instance_method(:template_binding).bind(context).call
      end

      private

      def template_binding
        binding
      end
    end
  end
end
