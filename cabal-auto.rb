#!/usr/bin/env ruby

require 'open3'

CABAL_FILE = ARGV[0] || Dir.glob("*.cabal")[0]
$stderr.printf("Cabal File: %s\n", CABAL_FILE)

cabal_out, cabal_err = Open3.popen3("cabal build") {|stdin, stdout, stderr, thread|
  stdin.close
  [stdout.read, stderr.read]
}

if cabal_err == nil
  $stderr.puts("No error")
  exit(0)
elsif cabal_err !~ /^    It is a member of the hidden package `(.+?)'\.$/
  $stderr.puts(cabal_err)
  exit(0)
else
  # package
  package = $1
  if package =~ /\A(.+)-(\d+(\.\d+(\.\d+(\.\d+)?)?)?)\Z/
    pkg_name = $1
    pkg_version = $2
  else
    pkg_name = package
    pkg_version = nil
  end

  # target
  target = nil
  cabal_out.each_line {|l|
    if l =~ /^Preprocessing executable '(.+?)' for /
      target = $1
    end
  }

  # log
  $stderr.printf("Target: %s\n", target)
  $stderr.printf("Package: %s\n", package)
  $stderr.printf("Package Name: %s\n", pkg_name)
  $stderr.printf("Package Version: %s\n", pkg_version || "nil")

  # rewrite the cabal file
  open(CABAL_FILE + ".tmp", "w") {|fout|
    open(CABAL_FILE, "r") {|fin|
      current_target = nil
      while l = fin.gets
        l.chomp!
        if l =~ /^(library|executable|test-suite)\s*$/i
          current_target = nil
        elsif l =~ /^(library|executable|test-suite)\s+(\S+)\s*$/i
          current_target = $2
        elsif l =~ /^\s+build-depends:/ && current_target == target
          if pkg_version
            ver_nums = pkg_version.split(".").values_at(0...4).map {|s| s.to_i }
            l << format(", %s >=%d.%d && <%d.%d", pkg_name, ver_nums[0], ver_nums[1], ver_nums[0], ver_nums[1] + 1)
          else
            l << format(", %s", pkg_name)
          end
        end
        fout.puts l
      end
    }
  }
  File.rename(CABAL_FILE + ".tmp", CABAL_FILE)

  exit(1)
end
