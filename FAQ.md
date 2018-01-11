# Frequently Asked Questions (or Frequent Assertions)

1. Why did you create this project?

    A. A few years ago I worked on converting the `IO` class in the Rubinius project from a 50/50 mix of C++ and Ruby to a 10/90 mix of C++ and Ruby. I became well acquainted with the API and the strange semantics of a lot of method calls. This project is a "clean sheet" redesign of the `IO` classes with an eye towards a simple API, unsurprising method semantics, proper inheritance structure, and a little bit of future-proofing.

2. This API is very different from the current Ruby IO classes; why will anyone use this different API?

    A. I believe there are a few reasons to use it. One, Ruby is approaching a future 3.0 release. Ruby uses semantic versioning which (in short) means that major releases may have breaking API changes that are not backward compatible with earlier versions. By introducing this project now, we can incorporate sound feedback and potentially evolve this project towards an acceptable solution for a new IO library in Ruby 3.0. Two, in my opinion the API will be simpler for beginners to understand and use. Pervasive use of keyword arguments makes the method calls easier to understand and their expectations less confusing. As an example, look at `IO#gets` which has multiple positional arguments, updates a global variable on every call, and is generally very confusing for a beginner. Three, this library is intended to be 100% written in Ruby with 0% in C, C++, Java, or some other system-level language. By providing a core library in Ruby, it will be more approachable to Ruby programmers who wish to contribute to the expansion and evolution of the Ruby community. Bug fixes can be contributed by a much wider audience (i.e. anyone who knows Ruby) versus today's situation where many bug fixes require knowledge of C (a large community itself but one that has small overlap with the Ruby community in general).

3. Can I run this library on the Matz Ruby Interpreter, JRuby, TruffleRuby, and Rubinius?

    A. Yes. The library is written 100% in Ruby. Access to syscalls on each host platform is provided via `FFI` (Foreign Function Interface) which allows Ruby to call those system functions directly. Each Ruby runtime provides FFI support.

4. Will this project provide 100% equivalent functionality to the current Ruby IO?

    A. I intend for this project to support IO on Files, Strings, TTYs, Named Pipes / FIFOs, Pipes, TCP Sockets, UDP Sockets, RAW Sockets, WebSockets, ZeroMQ Sockets, and provide sufficient infrastructure and support for expansion to other IO targets (e.g. SCTP, QUIC, TICP, RINA, etc.). This does not mean that every method call in Ruby's current IO will be duplicated in the new API. For example, current IO provides a multitude of ways to read from a file descriptor:

* `binread`
* `gets`
* `recv`
* `recv_io`
* `recv_nonblock`
* `recvfrom`
* `recvfrom_nonblock`
* `recvmsg`
* `recvmsg_nonblock`
* `read`
* `readbyte`
* `readchar`
* `readline`
* `readlines`
* `readpartial`
* `read_nonblock`
* `sysread`

    There is tremendous overlap between these calls which leads to confusion as to which one is correct to use for a given problem. This project will simplify that choice.

5. Will this project support my ancient operating system and it's possibly weird system calls?

    A. Target is to support POSIX as a baseline. If the ancient system conforms to POSIX, then it will be supported. As a general rule of thumb, if the operating system is earlier than Linux kernel 4.1, OSX 10.12, Windows 10, FreeBSD 11, OpenBSD 6, or NetBSD 7 then support will be spotty. Patches to the core system to support older systems will likely not be accepted; instead, a `ruby-io-patches` project could be created to collect patches for older systems and loaded only when necessary. I do not intend to pollute the core library to support systems 10+ years old.

### Design

6. How does the non-blocking or asynchronous IO support work?

    A. When the `Async` portion of the library is loaded, any call to its IO methods will setup the asynchronous infrastructure if it hasn't been started yet. The calling thread creates a new Fiber that acts as a Fiber Scheduler for all Fibers on that thread. Additionally, it starts up a new Thread to run an IOLoop. This thread never exits. Calling methods on the `IO::Async` classes passes responsibility to the local thread's Fiber Scheduler. The request is packaged up and sent to the IOLoop via a mailbox. The Fiber Scheduler then waits for a reply by blocking on an incoming mailbox. At this time, the calling thread goes to sleep. The IOLoop receives the request on its mailbox. If the request is for a blocking function (`open`, `close`, `fcntl`, etc.) the request is passed to a small thread pool to execute the blocking function. Upon completion, the request fulfills a private Promise which passes the result back to the correct Fiber Scheduler. If the request is nonblocking (e.g. `read`, `write`, `recv`, etc.) then the file descriptor is registered for the required operation with the Poller. When the Poller detects that the read/write will succeed, it executes the request. The request also fulfills a Promise which sends the result back to the correct Fiber Scheduler. The Fiber Scheduler wakes up, retrieves the promised result, and returns the result to the original calling Fiber. The Fiber wakes up, parses the result, and passes it back to the caller. Done.

7. That sounds like a lot of work; is `Async::IO` slow?

    A. In my preliminary tests, the nonblocking method calls are only a few percent slower than the blocking calls. Of course, all benchmarks are nonsense so make sure to test your specific requirement.

8. How does the library yield and resume so many Fibers?

    A. The library takes advantage of a lesser-used feature of Ruby Fibers called `transfer`. Ruby Fibers that use `Fiber.yield` and `Fiber#resume` are considered semi-coroutines. They are semi-coroutines because there is a parent/child relationship between the yielder and the resumer. Any fiber that is resumed *must* yield back to the fiber that resumed it originally. This behavior is insufficient to support the description above regarding how the async support works. Instead, we rely on `Fiber#transfer` which transforms Ruby's Fibers into a full-fledge coroutine. A regular coroutine can call into other Fibers/coroutines and does not need to yield back to its original caller.

    For a good discussion on this topic, see [this 2014 paper on distinguishing coroutines and fibers](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2014/n4024.pdf).

9. `Fiber#transfer` sounds interesting; is there a disadvantage to its use?

    A. Unfortunately, the great power provided by `Fiber#transfer` has some drawbacks. There is a [4 year old bug in the Matz Ruby Interpreter](https://bugs.ruby-lang.org/issues/9664) that prevents a Fiber from calling `Fiber.yield` or `Fiber#resume` once that fiber has ever called `Fiber#transfer`. This used to work in Ruby 1.9 so the hope is that eventually it will be fixed. This bug prevents transferred fibers from using external iterators (what we call `Enumerator`) from being used. An `Enumerator` uses a Fiber internally to yield successful elements of an `Enumerable` object via `Fiber.yield` and `Fiber#resume`.

    Additionally, the bug mentioned above also exists in Jruby, TruffleRuby, and Rubinius. They all conform so closely to the Matz Ruby Interpreter that they even allow the same bugs!

10. I need to scale my Ruby app to 50k socket connections; can this library scale with me?

    A. Hopefully it can and here's how. For one, the library will detect and use the most efficient select/poll mechanism available on your platform. That means it uses `kqueue` on BSD operating systems like FreeBSD and OSX, it uses `epoll` on Linux, and it falls back to `select` on other platforms. Second, the library is designed to allow for multiple IOLoops. As of this writing, it starts and runs a single IOLoop. However, there is no reason that multiple IOLoops could not be created to services 10s of thousands of sockets across multiple threads.

### Multi-thread Applications

11. The library uses `pread` for File IO which requires always passing in an offset! Why don't you support the Ruby IO style `read` which maintains a file pointer and position offset within the class?

    A. The current Ruby IO classes provide no guidance for how to properly use them in a multi-threaded application. Consequently many programmers pass a singular IO instance around to multiple threads and allow them to perform IO operations on a file, socket, etc. This behavior is undefined and usually leads to very difficult bugs to fix. Years back the core IO classes were modified to wrap certain operations in a mutex so that only one thread could perform the operation at a time. However, the fundamental issues remain. The IO class maintains "state" internally to track the current file pointer position.
    
    For example, due to the usage of mutexes within the IO library, every program that uses IO now pays the price for protection against possible multi-thread mutation. Even single-threaded programs pay this price!
    
    This project uses `pread` specifically because it forces the programmer to think about accessing the file correctly. Under the old style using `read` which maintains a file pointer, the programmer had to be very careful to coordinate IO access so that the file pointer was moved correctly. With `pread`, this issue disappears. The programmer is free to use the same IO object from multiple threads and issue simultaneous reads from it without worrying about the reads confusing each other! And the `pread` always returns the new potential offset so if the programmer wants to continue reading from that location they can pass that new value in to the next call.
    
    Additionally, the `IO::Enumerable` functionality hides some of this complexity (i.e. tracking offset) while still allowing multiple threads to safely issue reads. The call to `each` (and its variants) to step through a file takes an initial offset value but then internally maintains this value until the block is exited or the file hits EOF. This is all done without a mutex since each invocation of `each` (from multiple threads) maintains its own local variables. There is no global object state to protect.
    
    However, while this is possible it is still not recommended. While this may work fine for an unchanging file, it doesn't work very well for a stream like a pipe or socket. This is because streams are unseekable and an offset is not accepted for those file descriptor types.
    
    So any multi-threaded access to a single IO instance is allowed, it is highly discouraged. The programmer may set a global "multithread policy" which governs how multi-thread access is handled. It can be `silent`, `warn`, or prove `fatal` when detected. Expert programmers with very specific needs could probably override the default `warn` policy to `silent`. The policy incurs a much lower overhead than a mutex; it merely records the instantiating thread's identity and compares that identity to the accessing thread's ID upon method invocation. It's a quick and cheap comparison.

12. Why isn't my favorite magic global variable `$_` supported?

    A. A global variable is completely useless in a multi-threaded environment. If many threads are iterating through the same file using the same IO object, what is the true correct value of `$_`? It should probably be protected by a mutex to serialize access, but now that mutex is acting as a "performance gate" by inhibiting all threads accessing it. It's best to not use global variables at all.
    
    Since the File IO objects do not maintain any internal offset information for the file pointer, this information is returned upon the completion of any `read`, `write`, or `each` operation. It's up to the programmer to save and use this information on new `read` or `write` calls to place their bytes in the correct file location.
    
    Lastly, removing any vestiges of Ruby's PERL history are a good enough reason. :)

### Gems

13. None of the main gems I need to use for (HTTP | WebSocket | Rails | Redis | ...) can use your library; they are all written with Ruby's IO API in mind. How can I use this library with those gems?

    A. Great question and the hardest to answer. The simple answer is that new gems need to be created to utilize it much like there were gems written to support great projects like `EventMachine`, `Celluloid`, `Celluloid-IO`, `async`, and others. It is also possible to create an adapter layer that would translate the old-style Ruby IO API into calls that conform to this library's API. I may create such an adapter library at some point.

    It should be pointed out that most of those other libraries provide async Sockets only. This library tries to provide async or nonblocking access to Files, Sockets, TTYs, and other IO mechanisms so it's a much more general solution.

12. I have a question not listed here; how can I get an answer?

    A. Email me at git[at]chuckremes.com and I'll try to answer your question and add it to the FAQ.
