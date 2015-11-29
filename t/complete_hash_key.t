#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Test::More;

use Complete::Util qw(complete_hash_key);

local $Complete::Setting::OPT_WORD_MODE = 0;
local $Complete::Setting::OPT_FUZZY = 0;

test_complete(
    word      => 'a',
    hash      => {a=>1, aa=>1, ab=>1, b=>1, A=>1},
    result    => [qw(a aa ab)],
    result_ci => [qw(A a aa ab)],
);
test_complete(
    word      => 'c',
    hash      => {a=>1, aa=>1, ab=>1, b=>1, A=>1},
    result    => [qw()],
    result_ci => [qw()],
);

# TODO: opt:word_mode (but at least this has been tested in complete_array_elem.t)

subtest "opt:fuzzy" => sub {
    test_complete(
        word      => 'aple',
        fuzzy     => 1,
        hash      => {apple=>1},
        result    => [qw(apple)],
        result_ci => [qw(apple)],
    );
};

subtest "opt:map_case" => sub {
    test_complete(
        name      => 'opt:map_case=0',
        word      => 'a-',
        map_case  => 0,
        hash      => {qw(a-1 1 A-2 2 a_3 3 A_4 4)},
        result    => [qw(a-1)],
        result_ci => [sort qw(a-1 A-2)],
    );
    test_complete(
        name      => 'opt:map_case=1 (1)',
        word      => 'a-',
        map_case  => 1,
        hash      => {qw(a-1 1 A-2 2 a_3 3 A_4 4)},
        result    => [qw(a-1 a_3)],
        result_ci => [sort qw(a-1 A-2 a_3 A_4)],
    );
    test_complete(
        name      => 'opt:map_case=1 (2)',
        word      => 'a_',
        map_case  => 1,
        hash      => {qw(a-1 1 A-2 2 a_3 3 A_4 4)},
        result    => [qw(a-1 a_3)],
        result_ci => [sort qw(a-1 A-2 a_3 A_4)],
    );
};

done_testing();

sub test_complete {
    my (%args) = @_;
    #$log->tracef("args=%s", \%args);

    my $name = $args{name} // $args{word};
    my $res = [sort @{complete_hash_key(
        word=>$args{word}, hash=>$args{hash},
        ci=>0, word_mode=>$args{word_mode}, fuzzy=>$args{fuzzy}, map_case=>$args{map_case})}];
    is_deeply($res, $args{result}, "$name (result)") or explain($res);
    if ($args{result_ci}) {
        my $res_ci = [sort @{complete_hash_key(
            word=>$args{word}, hash=>$args{hash},
            ci=>1, word_mode=>$args{word_mode}, fuzzy=>$args{fuzzy}, map_case=>$args{map_case})}];
        is_deeply($res_ci, $args{result_ci}, "$name (result_ci)")
            or explain($res_ci);
    }
}
