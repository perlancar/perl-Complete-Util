#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Test::More;

use Complete::Util qw(complete_hash_key);

local $Complete::Common::OPT_CI = 0;
local $Complete::Common::OPT_MAP_CASE = 0;
local $Complete::Common::OPT_WORD_MODE = 0;
local $Complete::Common::OPT_FUZZY = 0;

test_complete(
    word      => 'a',
    hash      => {a=>1, aa=>1, ab=>1, b=>1, A=>1},
    result    => [qw(a aa ab)],
);
test_complete(
    word      => 'c',
    hash      => {a=>1, aa=>1, ab=>1, b=>1, A=>1},
    result    => [qw()],
);
test_complete(
    name      => 'arg:summaries',
    word      => 'a',
    hash      => {a=>1, aa=>1, ab=>1, b=>1, A=>1},
    summaries => {a=>2, aa=>3, ab=>4, b=>5, A=>6},
    result    => [
        {word=>'a' , summary=>2},
        {word=>'aa', summary=>3},
        {word=>'ab', summary=>4},
    ],
);
test_complete(
    name      => 'arg:summaries_from_hash_values',
    word      => 'a',
    hash      => {a=>1, aa=>2, ab=>3, b=>4, A=>5},
    summaries_from_hash_values => 1,
    result    => [
        {word=>'a' , summary=>1},
        {word=>'aa', summary=>2},
        {word=>'ab', summary=>3},
    ],
);

done_testing;

sub test_complete {
    my (%args) = @_;
    #$log->tracef("args=%s", \%args);

    my $name = $args{name} // $args{word};
    my $res = complete_hash_key(
        word => $args{word},
        hash => $args{hash},
        summaries => $args{summaries},
        summaries_from_hash_values => $args{summaries_from_hash_values},
    );
    #diag explain $res;
    is_deeply($res, $args{result}, "$name (result)") or explain($res);
}
