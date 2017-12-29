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

      ErrorPolicies = ['return_codes', 'exceptions']
      @error_policy = Internal::Backend::ErrorPolicy::ReturnCodes
      
      def self.error_policy
        @error_policy
      end
      
      def self.configure_error_policy(policy: :return_codes)
        policy = policy.to_s
        return [-1, nil] unless ErrorPolicies.include?(policy)
        @error_policy = case policy
        when 'return_codes'
          Internal::Backend::ErrorPolicy::ReturnCodes
        when 'exceptions'
          Internal::Backend::ErrorPolicy::Exceptions
        else
          Internal::Backend::ErrorPolicy::ReturnCodes
        end
        Config::Defaults.error_policy.check([0, nil])
      end
    end
  end
end
