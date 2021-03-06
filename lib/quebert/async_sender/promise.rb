module Quebert
  module AsyncSender
    # Decorates AsyncSender classes with an #async() proxy. This seperates
    # the concern of configuring job specific parameters, like :ttr, :delay, etc.
    # from calling the method.
    class Promise
      attr_reader :target, :opts, :job

      def initialize(target, opts={}, &block)
        @target, @opts, @block = target, opts, block
        self
      end

      # Proxies the method call from async to the target, then tries
      # to build a job with the targets `build_job` function.
      def method_missing(meth, *args)
        if @target.respond_to? meth, true # The second `true` argument checks private methods.
          # Create an instance of the job through the proxy and 
          # configure it with the options given to the proxy.
          @block.call configure @target.build_job(meth, *args)
        else
          super
        end
      end

      # Configures a job with the options provied to the Promise
      # upon initialization.
      def configure(job)
        @opts.each do |attr, val|
          job.send("#{attr}=", val)
        end
        job
      end

      # Methods/DSL that we mix into classes, objects, etc. so that we
      # can easily enqueue jobs to these.
      module DSL
        def async(opts={})
          Promise.new(self, opts) { |job| job.enqueue }
        end

        # Legacy way of enqueueing jobs.
        def async_send(*args)
          meth = args.shift
          beanstalk = args.last.delete(:beanstalk) if args.last.is_a?(::Hash)

          Quebert.deprecate "#async_send should be called via #{self.class.name}.async(#{beanstalk.inspect}).#{args.first}(#{args.map(&:inspect).join(', ')})" do
            async(beanstalk || {}).send(meth, *args)
          end
        end
      end
    end
  end
end