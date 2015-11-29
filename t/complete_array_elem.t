#!perl

use 5.010;
use strict;
use warnings;

use Test::More 0.98;

use Complete::Util qw(complete_array_elem);

local $Complete::Common::OPT_WORD_MODE = 0;
local $Complete::Common::OPT_MAP_CASE = 0;
local $Complete::Common::OPT_FUZZY = 0;
local $Complete::Common::OPT_CI = 0;

test_complete(
    word      => 'a',
    array     => [qw(an apple a day keeps the doctor away)],
    result    => [qw(a an apple away)],
);
test_complete(
    word      => 'an',
    array     => [qw(an apple a day keeps the doctor away)],
    result    => [qw(an)],
);
test_complete(
    word      => 'any',
    array     => [qw(an apple a day keeps the doctor away)],
    result    => [qw()],
);

test_complete(
    name      => 'opt:exclude',
    word      => 'a',
    array     => [qw(an apple a day keeps the doctor away)],
    exclude   => [qw(a apple foo)],
    result    => [qw(an away)],
);

subtest 'opt:ci' => sub {
    local $Complete::Common::OPT_CI = 1;
    test_complete(
        name      => 'opt:ci',
        word      => 'an',
        array     => [qw(An apple a day keeps the doctor away)],
        result    => [qw(An)],
    );
    test_complete(
        name      => 'opt:exclude (ci)',
        word      => 'a',
        array     => [qw(an apple a day keeps the doctor away)],
        exclude   => [qw(A Apple foo)],
        result    => [qw(a an apple away)],
        result    => [qw(an away)],
    );
};

subtest "opt:map_case" => sub {
    local $Complete::Common::OPT_MAP_CASE;

    $Complete::Common::OPT_MAP_CASE = 0;
    test_complete(
        name      => 'opt:map_case=0',
        word      => 'a-',
        map_case  => 0,
        array     => [qw(a-1 A-2 a_3 A_4)],
        result    => [qw(a-1)],
    );

    $Complete::Common::OPT_MAP_CASE = 1;
    test_complete(
        name      => 'opt:map_case=1 (1)',
        word      => 'a-',
        map_case  => 1,
        array     => [qw(a-1 A-2 a_3 A_4)],
        result    => [qw(a-1 a_3)],
    );
    test_complete(
        name      => 'opt:map_case=1 (2)',
        word      => 'a_',
        map_case  => 1,
        array     => [qw(a-1 A-2 a_3 A_4)],
        result    => [qw(a-1 a_3)],
    );
};

subtest "opt:word_mode" => sub {
    local $Complete::Common::OPT_WORD_MODE;

    $Complete::Common::OPT_WORD_MODE = 0;
    test_complete(
        name      => 'opt:word_mode=0',
        word      => 'a-b',
        word_mode => 0,
        array     => [qw(a-f-B a-f-b a-f-ab a-f-g-b)],
        result    => [qw()],
        result_ci => [qw()],
    );

    $Complete::Common::OPT_WORD_MODE = 1;
    test_complete(
        name      => 'opt:word_mode=1',
        word      => 'a-b',
        word_mode => 1,
        array     => [qw(a-f-B a-f-b a-f-ab a-f-g-b)],
        result    => [qw(a-f-b a-f-g-b)],
        result_ci => [qw(a-f-B a-f-b a-f-g-b)],
    );
    test_complete(
        name      => 'opt:word_mode=1 searching non-first word',
        word      => '-b',
        word_mode => 1,
        array     => [qw(a-f-B a-f-b a-f-ab a-f-g-b)],
        result    => [qw(a-f-b a-f-g-b)],
        result_ci => [qw(a-f-B a-f-b a-f-g-b)],
    );
};

subtest "opt:fuzzy" => sub {
    local $Complete::Common::OPT_FUZZY;

    $Complete::Common::OPT_FUZZY = 1;
    test_complete(
        name      => 'opt:fuzzy=1',
        word      => 'apl',
        fuzzy     => 1,
        array     => [qw(apple orange Apricot)],
        result    => [qw(apple)],
        result_ci => [qw(apple Apricot)],
    );
};

DONE_TESTING:
done_testing();

sub test_complete {
    my (%args) = @_;

    my $name = $args{name} // $args{word};
    my $res = complete_array_elem(
        word=>$args{word}, array=>$args{array}, exclude=>$args{exclude},
    );
    is_deeply($res, $args{result}, "$name (result)")
        or diag explain($res);
}
