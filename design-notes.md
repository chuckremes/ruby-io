(NOTE to anyone else reading this: the thoughts below are oftentimes stream of consciousness and used for the purposes of "rubber ducking". Not everything makes sense.)

# Async Design
When calling AsyncIO.open, the first thing that happens is the AsyncIO class confirms that it is properly setup. A private method (AsyncIO::Private::Configuration.setup?) is called. This class/method checks to see if the current thread has a _private_io object key attached. If so, setup has already been done. If not, it creates a _private_io object and attaches it to the thread. The _private_io object creates any structures it needs to track things (like mapping fiber IDs to fibers), spins up its own IOFiber (IO::Private::Fiber < Fiber?) and resumes it. At this point it is running in its own fiber and not the calling fiber. It finishes any setup it needs including starting up a dedicated IO Thread (or getting the already-setup IOThread), registering its IN and OUT boxes with the IOThread, and then calls Fiber.yield back to the original calling fiber. This yield operation will take us to the next line of code *after* the Fiber.new.resume from earlier. At this point, the IO operation can proceed.

The IO Thread has a mailbox/queue where it listens for requests from its client Fibers running in other threads. If those requests can be handled in a non-blocking manner then they are dispatched and processed immediately. If they will block, then the IO hands the work off to a Thread pool. Listening to a queue for responses from that thread pool happens in a non-blocking manner.

Back to the IO Fiber... To proceed on any IO op (open, close, read, write, etc), the calling fiber creates the requested operation and registers itself (the fiber) as part of the request. It then calls Thread.current[:_scheduler_].enqueue(request) which will send the request to the IOFiber via a queue (or Fiber.resume call). The IOFiber resumes while the calling fiber yields (from a call to resume?). The IOFiber now enters an infinite loop where it gets requests from other fibers within its thread and packages the request up for delivery to the IO Thread. Before sending the request, it records the calling Fiber's information so when a response (or timeout) is delivered it can resume the appropriate fiber and deliver the result. The IO fiber checks the incoming reply queue from the IO Thread in a blocking manner, so it will sleep the whole thread if no reply is waiting. This IO Fiber is essentially a fiber scheduler for this specific thread. It acts as the funnel for all incoming fiber IO requests and also matches replies back up with their callers.

That IO Fiber sleep may not be correct. Let's rubber duck it. Let's say we are running a AsyncIO::Socket.accept call in a Thread. This is a blocking call, so we want the calling fiber to sleep while waiting for a non-blocking call to #accept on this socket. When the IO Thread detects a new connection, it will send the result back to the fiber's IO fiber which will unpack the reply, match it to the calling fiber, and then resume that fiber. So it looks like it's okay for that fiber to sleep (see first sentence of this paragraph).


Async::File.open steps
* determine flags and mode
* create OpenRequest and pass in args
* enqueue OpenRequest on IOFiber (which causes suspension)
* IOFiber resumes and plucks off request
* records request by fiber_id and assigns a monotonically increasing sequence number to request
* passes modified request (seq no) to IOLoop and suspends itself waiting for reply by blocking on mailbox

* IOLoop pulls out latest request
* records request by fiber_id and seqno.
* if blocking, passes unmodified request to thread pool
* if nonblocking, directly executes requested operation

Blocking...
* thread pool pops request and runs it synchronously
* thread packages up reply and returns it to IOLoop through completion_mailbox

* IOLoop gets reply from completion_mailbox
* looks up original request by reply fiber id; removes request
* passes reply back to originating IOFiber

IOFiber
* picks up reply from mailbox
* looks up originating fiber using reply info
* removes original request
* delivers reply to originating fiber
* originating fiber takes results and passes through Policy.check(results)

Questions... 
Since we are passing fiber_id down as part of request, is there any real need to record that in the IOFiber or IOLoop?
  * In IOFiber, just record fibers by their id. Lookup is as simple as retrieving the fiber and passing reply to it.
  * In IOLoop, map fiber id to fiber's inbox. Just pass reply directly to inbox.
  * To handle timeouts, the timeout is a special case that shares the originating fiber's request seqno. If reply comes back, look up timeout and delete it if exists. If no timeout, just return reply. If timeout fires, need to mark seqno as expired so if a real reply comes along later it can be dropped.


LET'S TRY AGAIN
Problem:
A thread might have multiple fibers available to run. We need a thread-level fiber scheduler so that when a fiber "blocks" (yields?) to an I/O operation another fiber can be selected to run. Likewise, the IOLoop may return a reply or timeout to a thread's fiber scheduler and that fiber needs to look up the appropriate fiber and restart it.

If we use Fiber as a semicoroutine, then we have the usual asymmetric imbalance. That is, any Fiber that resumes another fiber can only have control "yield"ed back to it. It's a 1:1 relationship. This is too limiting. We need to treat Fiber as a full coroutine that we can transfer control from one fiber to another. Luckily Ruby has this with the Fiber#transfer method.

Only a single #resume is called by library and that is to *resume* the Scheduler Fiber the first time. All other fiber controls are handled via *transfer*.

So let's step through things again.

Scenario A - make blocking IO call from thread, 1 fiber

Caller Fiber
* Calling fiber makes "blocking" call
* Setup thread and fiber for async support
  ** Create IOLoop
  ** Create Fiber Scheduler
    * Resume Scheduler loop where it completes setup and yields
* Return back to calling thread & fiber
* Make IO request and enqueue it
  ** This *transfers* control from the calling fiber to the Scheduler fiber
* Caller receives a Reply and unwraps the value (or raises the Exception)
* Caller continues onward

Scheduler Fiber
* After yielding for setup, control is transferred from caller
* Transfer passes Request
* Record the Request by Fiber (Request includes fiber reference)
* Send Request to IOLoop via mailbox
* Block on waiting for a response from IOLoop
* Receive Reply from IOLoop mailbox
* Lookup originating fiber
* Transfer to original fiber and pass Reply

Scenario B - Listen on socket and Accept new connections; each socket gets its own fiber

Caller Fiber
* Calling fiber makes "blocking" call
* Same setup as above
* Make Accept IO request and enqueue it
* Caller receives Accept Reply, unwraps value, creates new Fiber and transfers to it with Reply args
* Caller is now suspended
* Caller receives Accept Reply, unwraps value, creates new Fiber and transfers to it with Reply args

Accept Fiber
* Created to handle newest incoming connection
* Read from socket
* Make Read IO Request and transfer control to Scheduler Fiber
* Caller receives Read Reply and processes it
* Close socket
* Fiber exits

Scheduler Fiber
* After yielding from setup, control is transferred from caller
* Record Request by Fiber
* Send Read Request to IOLoop via mailbox
* Wait for response from IOLoop
* This time we get another Accept Reply
* Lookup originating fiber
* Transfer to Accept Fiber

The only work that occurs is on a straight line through each fiber. When a fiber transfers control out to the Scheduler fiber, it does NOT get to run again until a Reply (which could be a Timeout) comes in for it. The Scheduler needs some work to pass back to the caller so it can resume otherwise the Scheduler fiber *BLOCKS* waiting for work. There is no situation where there is another Fiber ready to resume work on something... if it had work to do, it would already be running and the Scheduler would be suspended. So the "scheduler" is just doing some bookkeeping to track requests and match them up against their originators to deliver replies back. Not worthy of a rename though.

Fiber#transfer neatly resolves a major issue I had. With just yield/resume, I always had to yield a Reply back to the latest caller. If a Reply for another fiber came in, we were SOL. By using transfer we can ping pong around to various fibers and had off Replies as they come in.

COMMANDS
Let's talk about how commands should work. Initial thought was that the Request::Command hierarchy would be a struct to contain the method name and method arguments. Somewhere in the thread worker pool (or in the IOLoop) we would detect the kind of command was sent, and then directly call the syscall corresponding to that command. The command struct would provide the args, etc.

An alternative would be for the Command struct itself to contain a method that invokes the syscall directly. It already has access to the appropriate args. Just issue the call with the args and handle the outcome. Some commands have different error handling than others, so this let's us create specific handlers for each command type. Downside is that we need a command to mimic the structure of the larger class hierarchy. That is, if we are calling File.open, we need a Command::File::Open which is distinct from a Command::Pipe::Open. In this case, open works the same for files as for pipes, so maybe it isn't a good example? Perhaps `read` is a better example. 

Another idea is to pass a closure. Instead of creating a complex Command struct hierarchy, just have the original method capture the command and args in a closure (block). Pass that down for execution on the IO thread or in the worker pool. This has the added benefit of keeping the source code for the work close to its origin. One minor detail is that the block itself can't tell us if the code contents will block or nonblock. Hmmm... we can attach a singleton method to the block via `extend` using the WillBlockMixin or WontBlockMixin defining the `blocking?` method.

Adjusted idea...
When creating the BlockingCommand, the command will generate an empty promise which will ride along with the command. When the command executes, it fulfills/resolves the promise. When fulfilled, the Promise knows how to schedule itself on the IOLoop to be handled in the next iteration and get sent back to the originating IOFiber. That Promise can also be watched by a timeout timer and resolved by it, so the Promise itself needs some kind of CAS (compare-and-swap) so that it can only be resolved once without races.

Question is... should the Promise schedule itself on the IOLoop to get handed back to the originating IOFiber via the mailbox? Or, should the Promise just insert itself directly into that IOFiber's mailbox? I like the latter... less work for the IOLoop to do.

class BlockingCommand
  attr_reader :promise
  def blocking?; true; end
  
  def initialize(outbox:, &blk)
    @promise = Promise.new(mailbox: outbox) # outbox refers to originating fiber's mailbox
    @command = Proc.new do
      reply = blk.call
      @promise.fulfill(reply)
    end
  end
end

class Promise
  def initialize(mailbox:)
    @mailbox = mailbox
    @cas = AtomicFlag.new(true)
  end
  
  def fulfill(reply)
    if @cas.compare_and_set(true, false)
      # We only get here if we are the first to set new value
      # Post reply directly to originating IOFiber's mailbox
      @mailbox.post(reply)
    end
  end
end

open = BlockingCommand.new(mailbox: outbox) do
  rc = Platform.open(path, flags.to_i, mode.to_i)
  errno = rc < 0 ? Platform.errno : nil
  Reply.new(rc: rc, errno: errno, fiber: fiber)
end

How would this look for a nonblocking command? Let's sketch one out after rubber ducking. The command needs to know its file descriptor, for one. The command should know how to register/unregister the FD with the active polling mechanism. Instead of putting this logic into the command, the command should take a reference to the polling mechanism and know how to call the methods with correct args to do the work. This way we can encapsulate this logic in the polling mechanism itself rather than teaching every command how to handle select/epoll/kqueue.

Sometimes a read/write will "short pay" the request so instead of reading/writing X bytes it will only do (X - Y) bytes as a partial. We need to detect this. Question is should we return the partial and let the user deal with it or keep looping until the request is completed or we err out? Won't know this answer until I write the code and see.

In case of #accept, we need to fulfill and return a new promise each time we accept a new connection. Right now we are only creating a single Promise per Command so this needs more thought. If the Promise is scheduling itself directly on the calling Fiber loop and bypassing the IOLoop, we save on a bunch of record keeping. The command itself could know to generate a new Promise for every iteration. Again, won't really know how to handle this until I get knee deep into the code. Hmmm, maybe for #accept we determine if it has been passed a block. If so, the caller expects a Promise back for every connection. If no block, then it's a single call and after the #accept completes it should deregister itself.

Perhaps the idea above can be generalized for other commands too like read & write. If given a block then continue running and return a Promise for every X bytes read/written.

read = NonblockingCommand.new(mailbox: outbox, with_block: true/false) do
  # not sure...
  # if with_block is true, then generate a new promise for every iteration. If no block,
  # this this is a one-shot.
end

I might need to back up here and write the end user code with an ideal API. That API can then drive some of these decisions.

Blocking Ops
* open
* socket
* bind
* connect
* listen
* close
* shutdown

Nonblocking Ops
* accept (registers fd from listen)
* read
* write

Given the above, let's walk through setting up a socket server.
1. Making blocking call to allocate a socket fd
2. bind the socket fd to an address
3. Make blocking call to listen on the fd
4. Make nonblocking call to accept on listen_fd
  * Loop needs to record this FD. Length of this list determines length of eventlist for kevent. If Command (with associated FD) is oneshot, register it as such. If repeatable, register as such.
  * Loop needs to add this FD to changelist via kevent
    ** When calling kevent with a changelist, the eventlist is always zeroed. When calling kevent to retrieve events, the changelist is always zeroed. We want to keep these operations separated.
  * Setup timeout to be the minimum of [shortest timer, 1 second]
  * Call kevent with zero changelist and non-zero eventlist. eventlist length is determined by the length of array recording active non-blocking FDs. See first bullet under #4.
  * Process eventlist. FD from ident field can be used to lookup the recorded FD command. The associated command can provide a Promise that will take the data (or error) and return it to the original caller.

Just read through the Ruby IO and Socket rdoc again. The only method where it makes sense for it to take a block is #accept. Something like:

```ruby
io = Socket::TCP.new(ip: '192.168.1.5', port: 5555)
err = io.listen
raise 'failed to listen' if err.rc < 0
io.accept do |socket|
  # run in its own fiber
  # any call to IO methods will provide opportunity for fiber
  # to yield and other fibers to run.
  # do not do any infinite loops here without a sleep or io call.
  # socket is NOT implicitly closed at block termination
ensure
  socket.close
end
```

Alternately, we do provide a block-style for File.open where the file is closed at block termination. We could do something similar for Socket::TCP.new where it takes a block and closes the socket when done.

Create a Function module. This will contain methods to wrap all POSIX functions and return their results. These Function namespaced methods will then be called by both Sync and Async modules. No sense in defining these funtions in multiple places when they can be shared.

States
Let's say I want my newly created IO object to close its file descriptor. Once I do, calls to #read or #write should fail. I could just propagate up the OS errors back to the programmer but this is more "work" that the system should not be executing. We already know the FD is closed and these calls will fail, so fail early.

One way to handle this is by making the IO object utilize an internal Private object that contains all of the correct logic for the current IO state. A "normal" state object knows how to read/write, etc. A "closed" state object has all the same methods but these methods all immediately return an error that the file descriptor is closed. We could probably take a hint from the man pages. This "closed state" would be the EBADF IO state (invalid fd).

Valid states are:

Top 3 states imply "open"
|- Readonly
|- Writeonly
|- Readwrite
|- Closed
|- FailedOpen (same as Closed?)

I can foresee mixin modules that all for read and write. To make readwrite, include both.

How does this work with Pipes or Socket pairs? Probably no different. In a pipe pair, one is for reading the other is for writing. We could potentially wrap a pair in a Pair object so that read go to the read pipe/socket and writes go to the other one. This kind of composition isn't hard and might be useful. Upon reviewing the pipe(2) man page, this is probably the way to go. It creates pipe FDs in pairs. Composition would be nice.

Different topic...
For SyncIO, the #read/#write commands should return a new 'io' instance since it will track the file offset internally. To be threadsafe, we need to construct a new instance and update its offset ivar. The old instance should remain valid but since its offset can never change any new read on it will start at the same offset every time. Internally the object will use #pread.

# IO::Sync

The `Sync` module is the namespace dedicated to all classes handling blocking IO.

While the underlying operating system may allow passing flags to allow for non-blocking behavior, this class does not have any special support that operation at all. It would need to be explicitly handled by the programmer. For nicer non-blocking or asynchronous IO work, see `Async`.

## Inheritance Tree
Sync
|
|---------------------------------------------------------------------
|        |        |          |            |              |           |
FCNTL   Stat    Config     Timer       Block          Stream        IOCTL
                  |          |            |              |
                  |- Mode    |- Once      |- File        |-
                  |          |            |              |
                  |- Flags   |- Repeat    |- Directory   |-
                  |                       |              |
                  |- Spawn                |- String      |- Pipe -------- Pair
                                                         |              |
                                                         |- ZeroMQ    Process
                                                         |
                                                         |- TTY ------
                                                         |           |
                                                         |        Console
                                                         |
                                                         |- Socket
                                                               |
                                                               |- TCP
                                                               |- UDP
                                                               |- RAW
                                                               |- UNIX
                                                               |- Pair

All SyncIO works on ASCII-8BIT. To use Encodings, create an IO::Transcoder and pass in the SyncIO::Block or SyncIO::Stream instance. Do all read/write operations on the transcoder instance.

AsyncIO will inherit from SyncIO::Block, SyncIO::FCNTL, and SyncIO::Stat to avoid duplication of effort. None of these operations are truly non-blocking/asynchronous so they will be handed off to a thread pool for completion. The AsyncIO::Stream and AsyncIO::Timer classes can be truly non-blocking so this code may or may not inherit generic functionality from the SyncIO parent classes. To be determined.

Async
|
|-----------------------------------------------------------------------------
|                    |             |                 |     |      |           |
Block              Stream        Timer             FCNTL  IOCTL  Stat      "Enumerable/Convenience"
  |                  |             |
  |                  |             |_ Once
  |_ File            |_ Pipe       |
  |                  |             |_ Repeat
  |_ Directory       |_ TCP
                     |
                     |_ UDP
                     |
                     |_ TTY__ Console
                     |
                     |- Socket
                           |
                           |- TCP
                           |- UDP
                           |- RAW
                           |- Pair


IO
|
|---------------------------------------------------------------------------------
|                     |               |              |            |              |
Internal            Async            Sync         Config      Constants      Transposer
   |
   |
   |-- Private
   |
   |-- Platforms -- Functions, et al

Each SyncIO or AsyncIO io object will have a stat function so we can retrieve information on the open file descriptor. That method will likely delegate to Stat.fstat which will return an instance of Stat. This way we stat the file once and can (at our leisure) get various details from it such as birthtime, file type, etc. without re-stat'ing the file for each inquiry. Stat.lstat and Stat.stat will also exist and behave similarly.

The IO::Internal::Platforms::Functions namespace will contain small Ruby methods that call the POSIX functions and return their values and errno. These Functions can be shared between the Sync and Async child branches since everyone is making the same system call(s). For those calls that always block (and will need to be sent to a thread pool for async delivery), the Async classes can call their Sync equivalents directly. No need to write that code twice either.

IOCTL
Need to investigate this a bit more. The ioctl for sockets shows quite a few macros for handling addresses and such. If ioctl is the only exposure for these things then I'll likely need to support this even though all of ioctl is supported via C Macros. Will need C function wrappers for the macros. Hopefully all functionality is exposed via other utilities like get/setsockopt, getsockname, etc. Same for fileio.h and tty.h. Sigh. Good article: https://stackoverflow.com/questions/15807846/ioctl-linux-device-driver

Tranposer
The core IO classes deal with 8-bit bytes exclusively. They have no notion of "character" or multi-byte character. To get this behavior, there is a `Transposer` class which can either wrap an existing IO (composition) or the IO can extend the TranposerMixin. This class provides the Encoding support to read/write characters in all their myriad forms. It will provide an `each_char` method. If used as a Mixin, then it overrides the built-in `each` method to work on char boundaries. The old `each` method is renamed `each_byte` and remains available for use. A convenience mixin provides `each_line`

ONLY LOAD WHAT WE NEED
Restructure so that we can load only what we want/need. e.g.
  require 'io/async' # loads io/config, io/private, io/async and subdirs
  require 'io/async/socket' # loads io/config, io/private, io/async/socket
  require 'io/sync/file' # loads io/config, io/private, io/sync/file
  require 'io' # loads everything

NEXT
* get Sync read implemented
* get Sync write implemented
* get Async read/write implemented
* get Sync socket/listen/bind/connect/accept implemented
* get Async socket/listen/bind/connect/accept implemented
* do NOT get sidetracked by fcntl, rearranging inheritance hierarchies, etc. Implement the MINIMUM necessary to get the above bullets done!! Refactor later!!
* audit for imperative shell, functional core

def write_append(&blk)
  offset = Stat.fstat(@fd).length # get file size
  loop do
    bytes = yield(self, offset)
    offset += bytes
  end
end

Use like:
write_append do |io, current_offset|
  bytes_written = io.write(offset: current_offset, buffer: some_string)
  bytes_written # must pass back number of bytes written to adjust offset
end

NOTE
To prevent writes from being lost when the Ruby runtime is exiting, the main thread will need to somehow join on the IOLoop and signal it to exit upon completion. I imagine this means the IOLoop will need to deregister all of its FDs and let the loop cycle at least once to flush any pending writes. This could be tricky.

UNIX domain sockets do NOT provide out-of-band data like TCP sockets. Neither do UDP sockets.

All socket combinations:
AF_INET, SOCK_STREAM, IPPROTO_TCP => TCP v4 socket (sockaddr_in)
AF_INET, SOCK_DGRAM, IPPROTO_UDP => UDP v4 socket (sockaddr_in)
AF_INET6, SOCK_STREAM, IPPROTO_TCP => TCP v6 socket (sockaddr_in6)
AF_INET6, SOCK_DGRAM, IPPROTO_UDP => UDP v6 socket (sockaddr_in6)
AF_INET, SOCK_RAW, IPPROTO_RAW => RAW v4 socket
AF_INET6, SOCK_RAW, IPPROTO_RAW -> RAW v6 socket
AF_UNIX, SOCK_STREAM, ?? => UNIX socket (sockaddr_un)
AF_UNIX, SOCK_DGRAM, ?? => UNIX socket (sockaddr_un)

STATES FOR SOCKETS
For UDP:
* open and unconnected (must use sendto, recvfrom)
* connected (can use send/recv)
* closed

TCP:
* open
* named (connected)
* closed

http://diranieh.com/SOCKETS/SocketStates.htm

Class structure could look like this:
We have a shell class that provides all of the methods for the given object. These methods
all delegate to an internal @context ivar where the actual business logic lives. When a new socket
opens, the @context is set to the Open behavior. In this state, the socket can really only bind, connect, and sendto (which does an implicit connect). This forces a state change to Connected. We update 
the @context to Connected behavior. When we close the socket, it updates @context to Closed.
Each of these internal behavior objects responds to all methods though they will do different 
things based upon the state.

Delete a message to the internal context safely.
def safe_delegation  #(&blk)
  @mutex.synchronize do
    yield(@context)
  end
end

def change_context_to(klass, **args)
  # context has internal state, it's just immutable because it's
  # only set at instantiation
  @context = klass.new(**args)
end

Called like:
def bind(addr)
  safe_delegation do |context|
    rc, errno = context.bind(addr)
    if rc > 0
      change_context_to(Named, addr: addr)
    end
    [rc, errno]
  end
end

By convention the @context ivar is only directly accessed in #safe_delegation and #change_context_to. Those are the only two methods that can read or modify the ivar directly. Everwhere else that ivar is used within a block where it's passed in as a block argument. This prevents those blocks from resetting @context (though they could... but it would defy the convention).

We will probably need to nest the behavior change down one level. The outer shell should have no notion of current state. It delegates to the behavior object by sending a message to it. The return value may include a new behavior to take the place of the old behavior. So, the shell needs to manage the mutex so that only one state/behavior change can be in flight at a time.

Example:

class SocketShell
  def inititalize(**args)
    ...
    @context = Open.new(**args)
  end
  
  def bind(addr)
    safe_delegation do |context|
      behavior, rc, errno = context.bind(addr)
      update_context(behavior)
      [rc, errno]
    end
  end
  
  def safe_delegation
    @mutex.synchronize do
      yield @context
    end
  end
  
  def update_context(behavior)
    @context = behavior
  end
end

class Open
  def initialize(**args)
    ...
  end
  
  def bind(addr)
    rc, errno = Platforms::Functions.bind(@fd, addr)
    if rc > 0 # success!
      # state change, so return new behavior
      behavior = Named.new(**args)
    else
      behavior = self # no state change, return same concrete state
    end
    [behavior, rc, errno]
  end
end

GETADDRINFO
This is a real workhorse of a function. 
AI_FAMILY types:
ai_socktype: SOCK_STREAM, SOCK_DGRAM, and SOCK_RAW (STREAM implies TCP, DGRAM implies UDP)
ai_protocol: IPPROTO_UDP or IPPROTO_TCP or IPPROTO_RAW

SOCKET CREATION
The call to socket(2) allows for the programmer to pass the domain, type, and protocol directly. However, I am making the choice to not expose this particular method. To create a socket, the creation must use the values from a valid addrinfo struct. So the process to create a socket will look something like this:

socket = Socket.open(hostname: host, port: service, tcp4: true)

https://stackoverflow.com/questions/5385312/ipproto-ip-vs-ipproto-tcp-ipproto-udp

The call above will call getaddrinfo behind the scenes and get the first IPv4 address that conforms to the given hostname and port. Ultimately this will filter down to a call to Socket.new(addrinfo: info). That initializer might be private so that the programmer is forced to always go through class method helpers.

Why limit the programmer's choices? Well, the current Socket API in Ruby provides every option and as a result exposes a pretty messy API. There should be certain well-worn paths that easily allow the programmer to accomplish the most common tasks. This is in the form of a good API. Yes, it may take away some choices but it's simpler and more powerful.

UNIX DOMAIN sockets
Interesting note that one side needs to bind and connect. The `bind` is implicit in other protocols but needs to be explicit for domain sockets.
https://stackoverflow.com/questions/3324619/unix-domain-socket-using-datagram-communication-between-one-server-process-and

PIPES
Makes no sense to create a single-ended pipe. When using `pipe` syscall, it creates a reader and a writer pair of FDs that are associated with the same pipe. Kind of like `socketpair` in the sense that a single syscall sets up the relationship.

DIRECTORIES
Many of the current methods on Ruby's Dir seem pointless. Methods like #tell, #read, etc are strange. Might just be my ignorance of the utility of these functions, so research it a bit. 
For new Dir class, thinking that it won't returns Strings as pathnames. We should also return a URL (universal record locator) object. This will, of course, have a #to_s method on it so someone can get a string if they really want it. Dir#each should take keyword args so the programmer can control some behavior.
For encoding, provide a IO::TransposeDir or similar. Need to figure out that hierarchy.
Dir.glob is going to be fun to implement in Ruby. Hear there are lots of performance issues so we'll need to be smart and maybe a bit clever.

EACH
Thinking that this should be supported as a mixin. The module would contain something similar to the Rubinius EachReader class. However, I'm thinking it should be broken down even more granularly so that there is a EachLimitReader, EachSeparatorReader, etc. Not sure this makes sense so pay attention when implementing.

Also, the #each methods should handle buffering. The "limit" readers can pretty easily request the specific number of bytes. The "line" or "separator" readers cannot. They need to read in some PAGE_SIZE quantity and return the lines to the caller. But the extra bytes read should not be thrown away; cache/buffer them locally until we run out and then read more.

Note that TruffleRuby just improved #gets and #each by making sure to only instantiate a single EachReader instead of instantiating a new one to every call to #each. Maybe have a private method __each__ that handles this instatiation and we just call into it from the public facing methods. Again, this will be easier to figure out during implementation.

The Transpose class(es) will provide their own #each methods that work on characters. When reading unicode, we know that 16-byte chars and 32-byte chars always take the same amount of space. Converting from bytes to chars is a simple multiplication. UTF-8 is trickier since a char can be anywhere from 1 to 4 bytes long. To read 80 chars requires reading AT LEAST 80 bytes and perhaps as many as 320 bytes.


FFI Select & FDSet
FFI can't wrap macros. Luckily the select(2) macros are fairly simple and the fd_set struct is the same on all platforms. FD_SETSIZE is a max of 1024 and defaults to 64 on some platforms. We'll always allocate 1024.

class FDSet < FFI::Struct
  layout \
    descriptors, [:uint8, 1024 / 8]

  def set?(bit_index:)
    byte_index, nibble_index = indexes(bit_index: bit_index)
    byte = self[:descriptors][byte_index]

    case nibble_index
    when 0; byte & 0b00000001
    when 1; byte & 0b00000010
    when 2; byte & 0b00000100
    when 3; byte & 0b00001000
    when 4; byte & 0b00010000
    when 5; byte & 0b00100000
    when 6; byte & 0b01000000
    when 7; byte & 0b10000000
    end
  end

  def set(fd:)
    byte_index, bit_index = indexes(index: fd)
    change(byte_index: byte_index, bit_index: bit_index, to_val: 1)
  end

  def clear(fd:)
    byte_index, bit_index = indexes(index: fd)
    change(byte_index: byte_index, bit_index: bit_index, to_val: 0)
  end

  private

  def change(byte_index:, bit_index:, to_val:)
    # for algorithm, see:  https://stackoverflow.com/questions/47981/how-do-you-set-clear-and-toggle-a-single-bit
    self[:descriptor][byte_index] ^= (-to_val ^ self[:descriptor][byte_index]) & (1 << bit_index);
  end

  def indexes(index:)
    byte_index = index / 8
    nibble_index = (index % 8) - 1 # remember to use 0-based indexing
  end
end

## SyncIO::Config

API for creating configuration objects used to open new IO streams. A file can be specified by either a path or a file descriptor (but not both). Similarly, files can be opened in different modes and with different flags. Rather than try to design a method to handle all of these different combinations (with its attendant complex method signature) we provide a configuration object facility which enforces the appropriate rules.

### Public Class Methods

* file_from(fd: nil, path: nil)

Returns a Config::File object. Given a `fd` argument, the `path` argument is ignored. So setting both results in only the `fd` argument being processed.

Given a `path` argument with a trailing slash, the slash will be removed.

```
config = SyncIO::Config.file_from(fd: 1, path: '/path/will/be/ignored')
io = SyncIO.new(file_config: config)
```

* mode_from()

## SyncIO::Abstract

Defines the API that all concrete classes should implement. Any methods that do not make sense in the context of the concrete class should raise `NotImplemenetedError`. For example, it is nonsensical for SyncIO::Directory#read to be called.

### Public Class Methods

* line_separator=(separator_string)

Defaults to "\r\n" on most operating systems. Any instances of SyncIO subclasses will set their default separator to the value of `SyncIO.line_separator` upon instantiation and make a local copy of it. If `SyncIO.line_separator` is modified, it does not effect any existing instances nor change their default separator.

* line_separator

Returns the default line separator. Defaults to "\r\n".

* path_separator=(separator_string)

Defaults to forward-slash "/" on most operating systems. Defaults to backward-slash "\" on Windows. Can be reset to any valid byte string.

* path_separator

Returns the default path separator. Defaults to "/" on most OSes or "\" on Windows.

* mode=(mode_struct)

* mode

Returns a SyncIO::Mode struct instance.

* flags=(flags_struct)

* flags

Returns a SyncIO::Flags struct.

* copy_stream(source_path:, destination_path:, copy_length: source.size, source_offset: 0)

::copy_stream copies source to destination. source and destination is a filename. source will be opened read only while destination will be opened write-only and will truncate existing file.

This method returns the number of bytes copied.

If optional arguments are not given, the start position of the copy is the beginning of the filename.

If copy_length is given, No more than copy_length bytes are copied.

If source_offset is given, it specifies the start position of the copy.

Both source and destination are closed upon completion.

Raises an IOError in the following situations: 
* source does not exist
* destination location is not writable
* destination runs out of space

* new(fd: nil, path: nil, mode: SyncIO.mode, flags: SyncIO.flags, &blk)

Creates a new SyncIO instance.

If fd is given, will open the given fd using the mode and flags.

If path is given, will open the given path using the mode and flags.

If both fd and path are given, raises an ArgumentError. If neither fd and path are given, raises an ArgumentError.

If mode or flags are not given, uses defaults. See SyncIO.mode and SyncIO.flags for more detail.

If blk is given, passes the SyncIO instance to the block for operations. Upon exiting the block, the instance is closed safely. The value of the block is the return value. When no blk is passed, returns a SyncIO instance whereupon it is the programmer's responsibility to close it.

### Public Instance Methods

* 


NEXT STEPS
* Write Async::TCP to mimic Sync::TCP
  ** Consider creating Internal::Backend::Sync and Async. The Sync would essentially call Platforms::Functions. The Async would call Async::Private to execute the function wrappers.
* Look at refactoring to share code but DO NOT DO IT (except for Structs though be careful about sync calls)
* Add kqueue Poller to support `accept`
* Add send/recv for Async sockets
* Add send/recv for Sync sockets
* REFACTOR
