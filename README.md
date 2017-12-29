# ruby-io
A clean sheet redesign of Ruby's IO class. Includes Synchronous and Asynchronous implementations of all major components.

This project exists to try out some ideas. I expect a few blind alleys before I settle on the API that I like and a good implementation to back it.

# Goals
* Provide Synchronous IO with a modern API for best single-threaded straight line performance
* Provide Asynchronous / Nonblocking IO with a modern API for the best multi-threaded performance
* Implement the State pattern internally to simplify error handling and eliminate a lot of hairy if/then/else logic
* Utilize keyword arguments everywhere to simplify and clarify method signatures
* Allow for the new IO classes to live side-by-side with the core IO classes in Ruby (no namespace conflicts)
* New classes include a sane class inheritance and composition structure
* Only expose POSIX-compliant functions
* Allow programmer to choose Error reporting policy; built-in choices to include POSIX-style return codes with errno, and Exceptions. One or the other will be active per IO instance.
* Allow programmer to choose Multithread reporting policy for when using objects across multiple threads: silent, warn, fatal options
* Move unicode support to the periphery of the IO classes and only incur unicode overhead when the programmer chooses to use it

## To Do Before First Public Release as Gem
* Multithread Policy - implement checks & warnings
* Initial #each implementation
* Start documentation with examples
* Hook up Error Policy for return codes and exceptions
* Modify all methods to return a Result object instead of an array or hash
* Initial IO::Transpose wrapper implementation
* Sketch out remaining class inheritance and put in stubs (UDP, Pipe, FIFO/NamedPipe, IOCTL, TTY, StringIO)
* Stub Error/Exception hierarchy
* Provide hooks for tracking IO statistics like bytes read/written; define API

## Philosophy
The current Ruby IO classes are over 20 years old. As a result, they suffer from a few shortcomings. This project hopes to resolve several issues with the current classes.

1. They grew "organically" over time, so the initial design and inheritance structure has been severely abused.
2. The classes reflect an older and out-of-style concept on how IO should work.
3. The classes are intended to run on older Rubies unchanged, so some newer language features such as keyword arguments are rarely used.
4. Heavy dependence on positional arguments (see IO#each for an example) and reliance on global magic variables make for a confusing and difficult API.

The redesign will address some of these issues in the following ways:

1. Keyword arguments will be heavily used by all methods. This resolves the issue of "positional arguments" and makes the API easier to read.
2. Both synchronous and asynchronous classes will be offered. For those programmers that need the best straight-line performance in a single thread, the synchronous classes will be a great choice. For those that are writing multi-threaded applications, the asynchronous classes may be a better choice for scalability.
3. The inheritance structure for all classes will make sense. Principle of least surprise will govern many choices.
4. Sensible defaults will be offered, but expert programmers can override these defaults for different behavior.
5. Concurrency and parallelism are important for future scalability. These classes assume the programmers will make sensible choices about parallelism and will warn when multiple threads attempt to utilize the same object instances.
6. With Ruby release 1.9, unicode features were added to all IO. Every program pays a substantial penalty for dealing with (potential) multi-byte characters even when dealing with regular binary data. With the introduction of IO::Transpose classes, the base IO classes work exclusively with 8-bit bytes. If unicode support is required, the IO::Transpose wrapper adds this functionality. The programmer only pays this toll when necessary and by choice, so the default is always fast.

### Error Policy

### Load Only Necessary Pieces

### Wrapper Classes
IO::Transpose
IO::Enumerable
Thread warnings

(c) Chuck Remes 2018