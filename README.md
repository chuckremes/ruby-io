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

## Runtime Support
Tested and works on:
* MRI 2.4.0, 2.5.0, 2.6.0dev
* Rubinius 3.87 (minimum required version)
* TruffleRuby (master as of 20171230)
* JRuby (master as of 20180102)
  ** The default Multithread policy warns about accessing IO methods from multiple threads. I haven't chased this down yet but I guess that JRuby's fiber pooling may be involved. Fibers are backed by a thread and can migrate between threads in a pool.

## Platform Support
Tested and working on:
* OSX 10.12.6 and 10.13.2 (native kqueue support)
* Linux kernel 4.13 (native epoll support)

## Philosophy
Please refer to the [FAQ](FAQ.md) for this topic.

### Examples

(c) Chuck Remes 2018