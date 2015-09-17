#!perl

use 5.010;
use strict;
use warnings;

use Test::More 0.98;

use Complete::Util qw(complete_array_elem);

local $Complete::Setting::OPT_FUZZY = 0;

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
    name      => 'ci',
    word      => 'an',
    array     => [qw(An apple a day keeps the doctor away)],
    result    => [qw()],
    result_ci => [qw(An)],
);

test_complete(
    name      => 'opt:exclude',
    word      => 'a',
    array     => [qw(an apple a day keeps the doctor away)],
    exclude   => [qw(a apple foo)],
    result    => [qw(an away)],
);
test_complete(
    name      => 'opt:exclude (ci)',
    word      => 'a',
    array     => [qw(an apple a day keeps the doctor away)],
    exclude   => [qw(A Apple foo)],
    result    => [qw(a an apple away)],
    result_ci => [qw(an away)],
);

subtest "opt:map_case" => sub {
    test_complete(
        name      => 'opt:map_case=0',
        word      => 'a-',
        map_case  => 0,
        array     => [qw(a-1 A-2 a_3 A_4)],
        result    => [qw(a-1)],
        result_ci => [qw(a-1 A-2)],
    );
    test_complete(
        name      => 'opt:map_case=1 (1)',
        word      => 'a-',
        map_case  => 1,
        array     => [qw(a-1 A-2 a_3 A_4)],
        result    => [qw(a-1 a_3)],
        result_ci => [qw(a-1 A-2 a_3 A_4)],
    );
    test_complete(
        name      => 'opt:map_case=1 (2)',
        word      => 'a_',
        map_case  => 1,
        array     => [qw(a-1 A-2 a_3 A_4)],
        result    => [qw(a-1 a_3)],
        result_ci => [qw(a-1 A-2 a_3 A_4)],
    );
};

{
    test_complete(
        name      => 'opt:fuzzy',
        word      => 'apl',
        fuzzy     => 1,
        array     => [qw(apple orange Apricot)],
        result    => [qw(apple)],
        result_ci => [qw(apple Apricot)],
    );
}

done_testing();

sub test_complete {
    my (%args) = @_;

    my $name = $args{name} // $args{word};
    my $res = complete_array_elem(
        word=>$args{word}, array=>$args{array}, exclude=>$args{exclude},
        fuzzy=>$args{fuzzy}, ci=>0, map_case=>$args{map_case});
    is_deeply($res, $args{result}, "$name (result)")
        or diag explain($res);
    if ($args{result_ci}) {
        my $res_ci = complete_array_elem(
            word=>$args{word}, array=>$args{array}, exclude=>$args{exclude},
            fuzzy=>$args{fuzzy}, ci=>1, map_case=>$args{map_case});
        is_deeply($res_ci, $args{result_ci}, "$name (result_ci)")
            or diag explain($res_ci);
    }
}
