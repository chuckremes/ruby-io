
## To Do Before First Public Release as Gem
* Initial IO::Transcode wrapper implementation
  ** ASCII_8BIT so we can get #each with a +separator+  -- done
  ** UTF-8 so I can flesh out the #read_to_char_boundary logic -- done
  ** Will need to refactor EachReader class(es) so random IO can use pread/pwrite and streaming IO uses read/write; remaining logic should be unchanged
* Start documentation with examples
  ** DONE - echo example
* done - UDP implementation (necessary to finish transcoder wrapper)
* refactor AddrStruct classes (and related) so there are NOT duplicates for linux and BSD. Only platform-specific differences should be in the linux and bsd trees.
* Stub Error/Exception hierarchy
* Hook up Error Policy for return codes and exceptions
* Modify all methods to return a Result object instead of an array or hash
  ** If I go this direction, the Result object should be created as close to the code boundary as possible
* Sketch out remaining class inheritance and put in stubs (Pipe, RAW, FIFO/NamedPipe, IOCTL, TTY, StringIO, Stat, Utils, IPC / shared memory, datalink / bpf / RAW?)
* DONE - Add rubocop to project and fix its complaints. Make it part of the check-in process so we stay in tight conformance.

## To Do
* Provide hooks for tracking IO statistics like bytes read/written; define API
* RAW socket support
* Shared memory / IPC support?
* Change Platforms module to POSIX?
  ** Should consider also supporting some functions that are platform-specific in its own namespace. Thinking of #writev and copy_file_range(2) which are not part of POSIX.
* Hook up `timeout:` arg in async methods so it actually does something
* Get real atomic reference support for main Rubies instead of current hack
* Expose a `poller` object for both Sync and Async classes; not sure what this would look like yet but suggest it delegates all read/write registration to actual Poller instance (for Async). For Sync, not sure.
* Need a supportable way to generate FFI structs for all major target platforms; considering c2ffi project (on github) but the ruby-c2ffi needs a bunch of fixes.
* Refactor inheritance structure and break out shared code to either parent classes or (more likely) to modules to DRY things up.
* Allow for multiple IOLoops per process; probably map threads to an IOLoop by hashing the thread's object_id or #hash to 0-N where (N-1) is number of IOLoop threads. e.g. (Thread.current.object_id % LOOP_COUNT) => provides a value 0 to N-1. Simple.
  Alternately, consider allowing fibers from within the same thread to dispatch to multiple IOLoops. That is, use Fiber.current.hash to pick the IOLoop to dispatch the work. Reason for this is to allow for better parallelism when all of the work is being done by one or two main threads with hundreds or thousands of fibers. Need to be careful that a single FD is not shared amongst multiple IOLoops.
* Port async-dns project over to use this IO directly; rip out the `async` reactor stuff
* Use JMeter or similar tool to do some benchmarking of TCP perf

## Longer Term Fixes
* Ruby bug https://bugs.ruby-lang.org/issues/9664 prevents a fiber that has ever been transferred from yielding or resuming. This makes supporting Enumerators impossible. Generally speaking, it makes supporting any other Fiber-aware code very problematic because most code in the wild uses yield/resume instead of transfer. If any of that code calls an Async IO method, the fiber will be transferred so any subsequent call to Fiber.yield or Fiber#resume will blow up.
