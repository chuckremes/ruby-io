class IO
  module POSIX
    class << self
      def reply(rc:, errno:)
        {rc: rc, errno: errno}
      end

      # man -s 2 fcntl for description of purpose, return codes, and errno
      def fcntl(fd, command, args)
        rc = Platforms::Functions.fcntl(fd, command, args.to_i)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'fcntl_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 open for description of purpose, return codes, and errno
      def open(path, flags, mode)
        rc = Platforms::Functions.open(path, flags, mode)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'open_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 pipe for description of purpose, return codes, and errno
      def pipe(fd_array)
        rc = Platforms::Functions.pipe(fd_array)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'open_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 close for description of purpose, return codes, and errno
      def close(fd)
        rc = Platforms::Functions.close(fd)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'close_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 pread for description of purpose, return codes, and errno
      def pread(fd, buffer, nbytes, offset)
        rc = Platforms::Functions.pread(fd, buffer, nbytes, offset)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'read_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 read for description of purpose, return codes, and errno
      def read(fd, buffer, nbytes)
        rc = Platforms::Functions.read(fd, buffer, nbytes)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'read_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 write for description of purpose, return codes, and errno
      def write(fd, buffer, nbytes)
        rc = Platforms::Functions.write(fd, buffer, nbytes)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'write_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 pwrite for description of purpose, return codes, and errno
      def pwrite(fd, buffer, nbytes, offset)
        rc = Platforms::Functions.pwrite(fd, buffer, nbytes, offset)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'write_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 3 getaddrinfo for description of purpose, return codes, and errno
      def getaddrinfo(hostname, service, hints, results)
        rc = Platforms::Functions.getaddrinfo(hostname, service, hints.pointer, results)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'getaddrinfo_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 3 inet_ntop for description of purpose, return codes, and errno
      def inet_ntop(sa_family, addr, dst, dstlen)
        string = Platforms::Functions.inet_ntop(sa_family, addr, dst, dstlen)
        errno = string.nil? ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'inet_ntop_command', message: "string [#{string}], errno [#{errno}]")
        reply(rc: string, errno: errno)
      end

      # man -s 2 socket for description of purpose, return codes, and errno
      def socket(domain, type, protocol)
        rc = Platforms::Functions.socket(domain, type, protocol)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'socket_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 getsockopt for description of purpose, return codes, and errno
      def getsockopt(fd, level, optname, optval, optlen)
        rc = Platforms::Functions.getsockopt(fd, level, optname, optval, optlen)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'getsockopt_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 bind for description of purpose, return codes, and errno
      def bind(fd, addr, addrlen)
        rc = Platforms::Functions.bind(fd, addr, addrlen)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'bind_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 connect for description of purpose, return codes, and errno
      def connect(fd, addr, addrlen)
        rc = Platforms::Functions.connect(fd, addr, addrlen)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'connect_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 listen for description of purpose, return codes, and errno
      def listen(fd, backlog)
        rc = Platforms::Functions.listen(fd, backlog)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'listen_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 accept for description of purpose, return codes, and errno
      def accept(fd, addr, addrlen)
        rc = Platforms::Functions.accept(fd, addr, addrlen)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'accept_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 send for description of purpose, return codes, and errno
      def send(fd, buffer, bufferlen, flags)
        rc = Platforms::Functions.send(fd, buffer, bufferlen, flags)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'send_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 sendto for description of purpose, return codes, and errno
      def sendto(fd, buffer, bufferlen, flags, addr, addr_len)
        rc = Platforms::Functions.sendto(fd, buffer, bufferlen, flags, addr, addr_len)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'sendto_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 recv for description of purpose, return codes, and errno
      def recv(fd, buffer, bufferlen, flags)
        rc = Platforms::Functions.recv(fd, buffer, bufferlen, flags)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'recv_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end

      # man -s 2 recvfrom for description of purpose, return codes, and errno
      def recvfrom(fd, buffer, bufferlen, flags, addr, addr_len)
        rc = Platforms::Functions.recvfrom(fd, buffer, bufferlen, flags, addr, addr_len)
        errno = rc < 0 ? ::FFI.errno : nil
        Logger.debug(klass: self.class, name: 'recvfrom_command', message: "rc [#{rc}], errno [#{errno}]")
        reply(rc: rc, errno: errno)
      end
    end
  end
end
