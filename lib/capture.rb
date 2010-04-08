
def capture(*cmd, &block)
  # Run a command, wait for it to exit and return its output or throw an exception if it failed.
  #
  # Examples:
  #   capture("cat") => ""
  #   capture("cat"){|stdin| stdin.write('bar')} => "bar"
  #   capture("cat"){"foo"} => "foo"
  #
  # Raises RuntimeError if the subprocess fails

  pw = IO::pipe   # pipe[0] for read, pipe[1] for write
  pr = IO::pipe
  pe = IO::pipe
  
  pid = fork {
    pw[1].close
    STDIN.reopen(pw[0])
    pw[0].close

    pr[0].close
    STDOUT.reopen(pr[1])
    pr[1].close

    pe[0].close
    STDERR.reopen(pe[1])
    pe[1].close

    exec(*cmd)
  }

  pw[0].close
  pr[1].close
  pe[1].close
  stdin, stdout, stderr = pw[1], pr[0], pe[0]
  stdin.sync = true
  begin
    if block_given?
      if block.arity == 1
        yield(stdin)
      else
        stdin.write(yield)
      end
    end
    stdin.close unless stdin.closed?
    Process.waitpid(pid)
    if $?.exitstatus != 0
      raise "Child exited with status #{$?.exitstatus}: #{stderr.read}"
    else
      return stdout.read
    end
  ensure
    [stdin, stdout, stderr].each{|p| p.close unless p.closed?}
  end
end
