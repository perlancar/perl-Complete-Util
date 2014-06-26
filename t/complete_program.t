#!perl

# TODO

use 5.010;
use strict;
use warnings;

use File::Slurp::Tiny qw(write_file);
use File::Temp qw(tempdir);
use Test::More 0.98;
use Complete::Util qw(complete_program);

sub mkexe { write_file($_[0], ""); chmod 0755, $_[0] }

my $dir = tempdir(CLEANUP=>1);
mkdir("$dir/dir1");
mkdir("$dir/dir2");
mkexe("$dir/dir1/prog1");
mkexe("$dir/dir1/prog2");
mkexe("$dir/dir2/prog3");
mkexe("$dir/dir2/Prog4");
# XXX test non-execs (on filesystem that supports it)

{
    local $^O = 'linux';
    local $ENV{PATH} = "$dir/dir1:$dir/dir2";
    is_deeply(complete_program(word=>"prog"), ["prog1","prog2","prog3"]);
    is_deeply(complete_program(word=>"prog3"), ["prog3"]);
    is_deeply(complete_program(word=>"prog9"), []);

    is_deeply(complete_program(word=>"prog", ci=>1),
              [sort("prog1","prog2","prog3","Prog4")]);
}

subtest "win support" => sub {
    local $^O = 'MSWin32';
    local $ENV{PATH} = "$dir/dir1;$dir/dir2";
    is_deeply(complete_program(word=>"prog"), ["prog1","prog2","prog3"]);
    is_deeply(complete_program(word=>"prog3"), ["prog3"]);
    is_deeply(complete_program(word=>"prog9"), []);
};

done_testing;
