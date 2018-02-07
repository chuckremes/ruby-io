# ruby-io
A clean sheet redesign of Ruby's IO class. Includes Blocking and Nonblocking implementations of all major components.

This project exists to try out some ideas. I expect a few blind alleys before I settle on the API that I like and a good implementation to back it.

# Goals
* Be considered as the new core IO classes for Ruby 3.0
* New API
  * Provide Synchronous IO with a modern API for best single-threaded straight line performance
  * Provide Asynchronous / Nonblocking IO with a modern API for the best multi-threaded performance
  * Make both the blocking & nonblocking APIs consistent/identical. Switching between them shouldn't require any (?) code changes.
* Implement the State pattern internally to simplify error handling and eliminate a lot of hairy if/then/else logic
* Utilize keyword arguments everywhere to simplify and clarify method signatures
* Allow for the new IO classes to live side-by-side with the core IO classes in Ruby (no namespace conflicts)
* New classes include a sane class inheritance and composition structure
* Only expose POSIX-compliant functions
  * Syscalls that are platform-specific can be sideloaded via mixins or some other mechanism
* Allow programmer to choose Error reporting policy; built-in choices to include POSIX-style return codes with errno, and Exceptions. One or the other will be active per IO instance.
* Allow programmer to choose Multithread reporting policy for when using objects across multiple threads: silent, warn, fatal options
* Move unicode support to the periphery of the IO classes and only incur unicode overhead when the programmer chooses to use it
* Pure Ruby implementation; other runtimes could potentially load native code (C for MRI, Java for JRuby) if performance dictates.

## Runtime Support
Tested and works on:
* MRI 2.4.0, 2.5.0, 2.6.0dev
* Rubinius 3.87 (minimum required version)
* TruffleRuby (master as of 20171230)
* JRuby (master as of 20180102)
  * The default Multithread policy warns about accessing IO methods from multiple threads. There is an open issue (find number) regarding a bug where `Thread.current` is incorrectly reported for thread-backed Fibers. While it tracks the proper parent thread internally, it reports the actual pool thread backing the running Fiber.
  * This problem is tracked in Issues [1717](https://github.com/jruby/jruby/issues/1717) and [1806](https://github.com/jruby/jruby/issues/1806) in JRuby.

## Platform Support
Tested and working on:
* OSX 10.12.6 and 10.13.2 (native kqueue support)
* Linux kernel 4.13 (native epoll support)

## Philosophy
Please refer to the [FAQ](FAQ.md) for this topic.

### Examples

(c) Chuck Remes 2018