class IO
  module Platforms
    module Constants
      # modes (see chmod(2))
      if RUBY_ENGINE == 'rbx'
        S_IRUSR = Rubinius::Stat::S_IRUSR
        S_IWUSR = Rubinius::Stat::S_IWUSR
        S_IXUSR = Rubinius::Stat::S_IXUSR

        S_IRGRP = Rubinius::Stat::S_IRGRP
        S_IWGRP = Rubinius::Stat::S_IWGRP
        S_IXGRP = Rubinius::Stat::S_IXGRP

        S_IROTH = Rubinius::Stat::S_IROTH
        S_IWOTH = Rubinius::Stat::S_IWOTH
        S_IXOTH = Rubinius::Stat::S_IXOTH
      else
        S_IRUSR = 0400
        S_IWUSR = 0200
        S_IXUSR = 0100

        S_IRGRP = 040
        S_IWGRP = 020
        S_IXGRP = 010

        S_IROTH = 04
        S_IWOTH = 02
        S_IXOTH = 01
      end

      # flags (see open(2))
      # load from 'fcnt' for now for the sake of convenience. still figuring
      # out right way to detect and define constants on each platform so
      # in the short term I'm going to cheat.
      require 'fcntl'
      FD_CLOEXEC  = Fcntl::FD_CLOEXEC
      # commands
      F_DUPFD     = Fcntl::F_DUPFD
      F_GETFD     = Fcntl::F_GETFD
      F_GETFL     = Fcntl::F_GETFL
      F_GETLK     = Fcntl::F_GETLK
      F_RDLCK     = Fcntl::F_RDLCK
      F_SETFD     = Fcntl::F_SETFD
      F_SETFL     = Fcntl::F_SETFL
      F_SETLK     = Fcntl::F_SETLK
      F_SETLKW    = Fcntl::F_SETLKW
      F_UNLCK     = Fcntl::F_UNLCK
      F_WRLCK     = Fcntl::F_WRLCK

      # flags
      O_ACCMODE   = Fcntl::O_ACCMODE
      O_APPEND    = Fcntl::O_APPEND
      O_CREAT     = Fcntl::O_CREAT
      O_EXCL      = Fcntl::O_EXCL
      #O_NDELAY    = Fcntl::O_NDELAY
      O_NOCTTY    = Fcntl::O_NOCTTY
      O_NONBLOCK  = Fcntl::O_NONBLOCK
      O_RDONLY    = Fcntl::O_RDONLY
      O_RDWR      = Fcntl::O_RDWR
      O_TRUNC     = Fcntl::O_TRUNC
      O_WRONLY    = Fcntl::O_WRONLY

      PAGESIZE    = 4096 #Platforms.getpagesize

      module FCNTL
        FD_CLOEXEC  = Constants::FD_CLOEXEC
        # commands
        F_DUPFD     = Constants::F_DUPFD
        F_GETFD     = Constants::F_GETFD
        F_GETFL     = Constants::F_GETFL
        F_GETLK     = Constants::F_GETLK
        F_RDLCK     = Constants::F_RDLCK
        F_SETFD     = Constants::F_SETFD
        F_SETFL     = Constants::F_SETFL
        F_SETLK     = Constants::F_SETLK
        F_SETLKW    = Constants::F_SETLKW
        F_UNLCK     = Constants::F_UNLCK
        F_WRLCK     = Constants::F_WRLCK

        # flags
        O_ACCMODE   = Constants::O_ACCMODE
        O_APPEND    = Constants::O_APPEND
        O_CREAT     = Constants::O_CREAT
        O_EXCL      = Constants::O_EXCL
        #O_NDELAY    = Constants::O_NDELAY
        O_NOCTTY    = Constants::O_NOCTTY
        O_NONBLOCK  = Constants::O_NONBLOCK
        O_RDONLY    = Constants::O_RDONLY
        O_RDWR      = Constants::O_RDWR
        O_TRUNC     = Constants::O_TRUNC
        O_WRONLY    = Constants::O_WRONLY
      end
    end
  end
end
