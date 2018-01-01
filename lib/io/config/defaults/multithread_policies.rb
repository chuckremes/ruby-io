class IO
  module Config
    class Defaults
      MultithreadPolicies = ['silent', 'warn', 'fatal']
      @multithread_policy = Internal::Backend::MultithreadPolicy::Warn
      
      def self.multithread_policy
        @multithread_policy
      end
      
      def self.configure_multithread_policy(policy: :warn)
        policy = policy.to_s
        return [-1, nil] unless MultithreadPolicies.include?(policy)
        @multithread_policy = case policy
        when 'silent'
          Internal::Backend::MultithreadPolicy::Silent
        when 'warn'
          Internal::Backend::MultithreadPolicy::Warn
        when 'fatal'
          Internal::Backend::MultithreadPolicy::Fatal
        else
          Internal::Backend::MultithreadPolicy::Warn
        end
        Config::Defaults.error_policy.check([0, nil])
      end
    end
  end
end
