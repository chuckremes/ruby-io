class IO
  module Async
    module Private
      # The reactor loop for handling all blocking and non-blocking
      # IO.
      class IOLoop
        class << self
          def current
            unless @loop
              Logger.debug(klass: self.class, name: :current, message: 'allocate IOLoop')
              @loop = IOLoop.new
            end
            @loop
          end
        end

        def initialize
          Logger.debug(klass: self.class, name: :new, message: 'allocating')
          @pipe_reader, @pipe_writer = self_pipe_trick_setup
          @poller = Internal::Backend::Async::Poller.new(self_pipe: @pipe_reader)
          @system_inbox = IOLoopMailbox.new(self_pipe: @pipe_writer)
          @mutex = Mutex.new

          # Store the mailboxes from all registered Fiber Schedulers. Command
          # Requests come in via this mailbox. Note that replies are sent back
          # directly to the Fiber Scheduler's mailbox when the command is
          # executed.
          @incoming = {}
          @thread = Thread.new do |t|
            io_loop
          end
          @pool = Pool.new
        end

        def register(fiber:, outbox:)
          Logger.debug(klass: self.class, name: :register, message: 'registering fiber')
          command = Request::System::Register.new(fiber.object_id, outbox)
          request = Request::Req.new(fiber, fiber.object_id, nil, nil, command)
          Logger.debug(klass: self.class, name: :register, message: 'posting request')
          @system_inbox.post request
        end

        def deregister(fiber:)
          Logger.debug(klass: self.class, name: :deregister, message: "deregistering fiber [#{fid}]")
          command = Request::System::Deregister.new(fiber.object_id)
          request = Request::Req.new(fiber, fiber.object_id, nil, nil, command)
          Logger.debug(klass: self.class, name: :deregister, message: 'posting request')
          @system_inbox.post request
        end

        def io_loop
          Logger.debug(klass: self.class, name: :io_loop, message: 'entering infinite loop')
          while true
            process_system_messages
            process_command_messages
          end
        end

        # Housekeeping tasks like registering or unregistering from the
        # IOLoop are handled here.
        def process_system_messages
          request = @system_inbox.pickup
          return unless request

          Logger.debug(klass: self.class, name: :process_system_messages, message: 'got a valid request, working...')
          if request.command.is_a?(Request::System::Register)
            Logger.debug(klass: self.class, name: :process_system_messages, message: 'matched')
            # Note we are assigning the fiber's outbox to inbox. From
            # this IOLoop's perspective, this is correct.
            command = request.command
            fiber_id, inbox = command.fiber_id, command.outbox
            add_incoming(id: fiber_id, mailbox: inbox)
            Logger.debug(klass: self.class, name: :process_system_messages, message: 'completed registration')
          elsif request.command.is_a?(Request::System::Deregister)
            fiber_id = request.command.fiber_id
            delete_incoming(id: fiber_id)
            Logger.debug(klass: self.class, name: :process_system_messages, message: "completed deregistration, [#{fiber_id}]")
          else
            Logger.debug(klass: self.class, name: :process_system_messages, message: 'unknown system message')
            raise "Unknown system message! [#{request.class}]"
          end
        end

        # Commands sent from various IOFiber loops are processed here.
        # We track all of those mailboxes via the @incoming ivar. We
        # pull messages from each mailbox and dispatch depending on
        # their type. Some commands require blocking so they are
        # dispatched to a worker pool. Other commands are non-blocking
        # and are handled in this loop directly.
        def process_command_messages
          immediate_count = 0

          incoming_values.each do |mailbox|
            request = mailbox.pickup
            next unless request # a non-blocking read from an empty queue returns nil

            Logger.debug(klass: self.class, name: :process_command_messages, message: "request #{request.inspect}")

            if request.blocking?
              dispatch_to_workers(request)
            else
              # Only process up to +max_allowed+ requests for immediate dispatch
              if immediate_count > @poller.max_allowed
                Logger.debug(klass: self.class, name: :process_command_messages, message: "immediate_count [#{immediate_count}] exceeded max!")
                break
              end
              immediate_count += 1
              immediate_dispatch(request)
            end
          end
          flush_immediate
        end

        def dispatch_to_workers(request)
          Logger.debug(klass: self.class, name: :dispatch_to_workers, message: 'dispatched blocking request, ' + request.inspect)
          request.selector_update(poller: @poller)
          @pool.dispatch(request)
        end

        def immediate_dispatch(request)
          Logger.debug(klass: self.class, name: :immediate_dispatch, message: 'dispatched non-blocking request, ' + request.inspect)
          # register with event loop
          # probably need to save a reference to this request somewhere. index by
          # FD and sequence_no maybe?
          request.selector_update(poller: @poller)
        end

        def flush_immediate
          @poller.poll
        end

        # Utilize the well-known technique for waking a sleeping/blocked selector
        # by writing to a pipe that is part of the selector's read set.
        #
        # This method allocates the file descriptors and sets them to non-blocking.
        # We also don't want these FDs to transfer to a fork, so set close-on-exec.
        #
        def self_pipe_trick_setup
          pipe_fds = ::FFI::MemoryPointer.new(:int, 2)
          reply = Platforms::Functions.pipe(pipe_fds)
          rc = reply[:rc]

          # fatal error if this allocation fails
          raise "Fatal error, self-pipe failed to allocate, rc [#{rc}] errno [#{FFI.errno}]" if rc < 0
          reader, writer = pipe_fds.read_array_of_int(2)
          Config::Defaults.syscall_mode_switch(mode: :blocking) do
            rc, errno = IO::FCNTL.set_nonblocking(fd: reader)
            raise "Fatal error, could not set reader to nonblocking, rc [#{rc}] errno [#{errno}]" if rc < 0
            rc, errno = IO::FCNTL.set_nonblocking(fd: writer)
            raise "Fatal error, could not set writer to nonblocking, rc [#{rc}] errno [#{errno}]" if rc < 0
            rc, errno = IO::FCNTL.set_close_on_exec(fd: reader)
            raise "Fatal error, could not set reader to close-on-exec, rc [#{rc}] errno [#{errno}]" if rc < 0
            rc, errno = IO::FCNTL.set_close_on_exec(fd: writer)
            raise "Fatal error, could not set writer to close-on-exec, rc [#{rc}] errno [#{errno}]" if rc < 0
          end
          Logger.debug(klass: self.class, name: 'IOLoop', message: "self-pipe, reader [#{reader}], writer [#{writer}]")

          [reader, writer]
        end

        def self_pipe_writer
          @pipe_writer
        end

        def add_incoming(id:, mailbox:)
          @mutex.synchronize { @incoming[id] = mailbox }
        end

        def delete_incoming(id:)
          @mutex.synchronize { @incoming.delete(id) }
        end

        def incoming_values
          values = @mutex.synchronize { @incoming.values.to_a }
        end

        IOLoop.current # make sure we allocate it during load step
      end
    end
  end
end
