#!perl

use 5.010;
use strict;
use warnings;

use Test::More 0.98;

use Complete::Util qw(complete_array_elem);

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
done_testing();

sub test_complete {
    my (%args) = @_;

    my $name = $args{name} // $args{word};
    my $res = complete_array_elem(
        word=>$args{word}, array=>$args{array}, ci=>0);
    is_deeply($res, $args{result}, "$name (result)")
        or diag explain($res);
    if ($args{result_ci}) {
        my $res_ci = complete_array_elem(
            word=>$args{word}, array=>$args{array}, ci=>1);
        is_deeply($res_ci, $args{result_ci}, "$name (result_ci)")
            or diag explain($res_ci);
    }
}
