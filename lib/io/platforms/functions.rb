class IO
  module Platforms
    module Functions
      class << self
        # man -s 2 fcntl for description of purpose, return codes, and errno
        def fcntl(fd, command, args)
          rc = Platforms.fcntl(fd, command, args.to_i)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'fcntl_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno}
        end

        # man -s 2 open for description of purpose, return codes, and errno
        def open(path, flags, mode)
          rc = Platforms.open(path, flags, mode)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'open_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno}
        end

        # man -s 2 close for description of purpose, return codes, and errno
        def close(fd)
          rc = Platforms.close(fd)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'close_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno}
        end

        # man -s 2 pread for description of purpose, return codes, and errno
        def read(fd, buffer, nbytes, offset)
          rc = Platforms.pread(fd, buffer, nbytes, offset)
          #rc = Platforms.read(fd, buffer, nbytes)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'read_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno}
        end

        # man -s 2 pwrite for description of purpose, return codes, and errno
        def write(fd, buffer, nbytes, offset)
          rc = Platforms.pwrite(fd, buffer, nbytes, offset)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'write_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno}
        end

        # man -s 3 getaddrinfo for description of purpose, return codes, and errno
        def getaddrinfo(hostname, service, hints, results)
          rc = Platforms.getaddrinfo(hostname, service, hints.pointer, results)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'getaddrinfo_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno, results: results}
        end

        # man -s 3 inet_ntop for description of purpose, return codes, and errno
        def inet_ntop(sa_family, addr, dst, dstlen)
          string = Platforms.inet_ntop(sa_family, addr, dst, dstlen)
          errno = string.nil? ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'inet_ntop_command', message: "string [#{string}], errno [#{errno}]")
          {rc: string, errno: errno}
        end

        # man -s 2 socket for description of purpose, return codes, and errno
        def socket(domain, type, protocol)
          rc = Platforms.socket(domain, type, protocol)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'socket_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno}
        end

        # man -s 2 bind for description of purpose, return codes, and errno
        def bind(fd, addr, addrlen)
          rc = Platforms.bind(fd, addr, addrlen)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'bind_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno}
        end

        # man -s 2 connect for description of purpose, return codes, and errno
        def connect(fd, addr, addrlen)
          rc = Platforms.connect(fd, addr, addrlen)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'connect_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno}
        end

        # man -s 2 listen for description of purpose, return codes, and errno
        def listen(fd, backlog)
          rc = Platforms.listen(fd, backlog)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'listen_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno}
        end

        # man -s 2 accept for description of purpose, return codes, and errno
        def accept(fd, addr, addrlen)
          rc = Platforms.accept(fd, addr, addrlen)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'accept_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno}
        end

        # man -s 2 send for description of purpose, return codes, and errno
        def ssend(fd, buffer, bufferlen, flags)
          rc = Platforms.ssend(fd, buffer, bufferlen, flags)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'send_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno}
        end

        # man -s 2 recv for description of purpose, return codes, and errno
        def recv(fd, buffer, bufferlen, flags)
          rc = Platforms.recv(fd, buffer, bufferlen, flags)
          errno = rc < 0 ? ::FFI.errno : nil
          Logger.debug(klass: self.class, name: 'recv_command', message: "rc [#{rc}], errno [#{errno}]")
          {rc: rc, errno: errno}
        end
      end
    end
  end
end
