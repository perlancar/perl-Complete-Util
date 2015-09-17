package Complete::Util;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Complete::Setting;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       hashify_answer
                       arrayify_answer
                       combine_answers
                       complete_array_elem
                       complete_hash_key
               );

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'General completion routine',
};

$SPEC{hashify_answer} = {
    v => 1.1,
    summary => 'Make sure we return completion answer in hash form',
    description => <<'_',

This function accepts a hash or an array. If it receives an array, will convert
the array into `{words=>$ary}' first to make sure the completion answer is in
hash form.

Then will add keys from `meta` to the hash.

_
    args => {
        arg => {
            summary => '',
            schema  => ['any*' => of => ['array*','hash*']],
            req => 1,
            pos => 0,
        },
        meta => {
            summary => 'Metadata (extra keys) for the hash',
            schema  => 'hash*',
            pos => 1,
        },
    },
    result_naked => 1,
    result => {
        schema => 'hash*',
    },
};
sub hashify_answer {
    my $ans = shift;
    if (ref($ans) ne 'HASH') {
        $ans = {words=>$ans};
    }
    if (@_) {
        my $meta = shift;
        for (keys %$meta) {
            $ans->{$_} = $meta->{$_};
        }
    }
    $ans;
}

$SPEC{arrayify_answer} = {
    v => 1.1,
    summary => 'Make sure we return completion answer in array form',
    description => <<'_',

This is the reverse of `hashify_answer`. It accepts a hash or an array. If it
receives a hash, will return its `words` key.

_
    args => {
        arg => {
            summary => '',
            schema  => ['any*' => of => ['array*','hash*']],
            req => 1,
            pos => 0,
        },
    },
    result_naked => 1,
    result => {
        schema => 'array*',
    },
};
sub arrayify_answer {
    my $ans = shift;
    if (ref($ans) eq 'HASH') {
        $ans = $ans->{words};
    }
    $ans;
}

sub __min(@) {
    my $m = $_[0];
    for (@_) {
        $m = $_ if $_ < $m;
    }
    $m;
}

# straight copy of Wikipedia's "Levenshtein Distance"
sub __editdist {
    my @a = split //, shift;
    my @b = split //, shift;

    # There is an extra row and column in the matrix. This is the distance from
    # the empty string to a substring of the target.
    my @d;
    $d[$_][0] = $_ for 0 .. @a;
    $d[0][$_] = $_ for 0 .. @b;

    for my $i (1 .. @a) {
        for my $j (1 .. @b) {
            $d[$i][$j] = (
                $a[$i-1] eq $b[$j-1]
                    ? $d[$i-1][$j-1]
                    : 1 + __min(
                        $d[$i-1][$j],
                        $d[$i][$j-1],
                        $d[$i-1][$j-1]
                    )
                );
        }
    }

    $d[@a][@b];
}

$SPEC{complete_array_elem} = {
    v => 1.1,
    summary => 'Complete from array',
    description => <<'_',

Will sort the resulting completion list, so you don't have to presort the array.

_
    args => {
        word     => { schema=>[str=>{default=>''}], pos=>0, req=>1 },
        array    => { schema=>['array*'=>{of=>'str*'}], req=>1 },
        ci       => { schema=>['bool'] },
        exclude  => { schema=>['array*'] },
        fuzzy    => { schema=>['int*', min=>0] },
        map_case => {
            summary => 'Treat _ (underscore) and - (dash) as the same',
            schema  => ['bool'],
        },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_array_elem {
    my %args  = @_;
    my $array    = $args{array} or die "Please specify array";
    my $word     = $args{word} // "";
    my $ci       = $args{ci} // $Complete::Setting::OPT_CI;
    my $fuzzy    = $args{fuzzy} // $Complete::Setting::OPT_FUZZY;
    my $map_case = $args{map_case} // $Complete::Setting::OPT_MAP_CASE;

    return [] unless @$array;

    # normalize
    my $wordn = $ci ? uc($word) : $word; $wordn =~ s/_/-/g if $map_case;

    my @words;
    for my $el (@$array) {
        my $eln = $ci ? uc($el) : $el; $eln =~ s/_/-/g if $map_case;
        next unless 0==index($eln, $wordn);
        push @words, $el;
    }

    if ($fuzzy && !@words) {
        my $factor = 1.3;
        my $x = -1;
        my $y = 1;

        my %editdists;
      ELEM:
        for my $el (@$array) {
            my $eln = $ci ? uc($el) : $el; $eln =~ s/_/-/g if $map_case;
            for my $l (length($wordn)-$y .. length($wordn)+$y) {
                next if $l <= 0;
                my $chopped = substr($eln, 0, $l);
                my $d;
                unless (defined $editdists{$chopped}) {
                    $d = __editdist($wordn, $chopped);
                    $editdists{$chopped} = $d;
                } else {
                    $d = $editdists{$chopped};
                }
                my $maxd = __min(
                    __min(length($chopped), length($word))/$factor,
                    $fuzzy,
                );
                #say "D: d(".($ci ? $wordu:$word).",$chopped)=$d (maxd=$maxd)";
                next unless $d <= $maxd;
                push @words, $el;
                next ELEM;
            }
        }
    }

    if ($args{exclude}) {
        my $exclude = $ci ? [map {uc} @{ $args{exclude} }] : $args{exclude};
        @words = grep {
            my $w = $_;
            !(grep {($ci ? uc($w) : $w) eq $_} @$exclude);
        } @words;
    }

    return $ci ? [sort {lc($a) cmp lc($b)} @words] : [sort @words];
}

*complete_array = \&complete_array_elem;

$SPEC{complete_hash_key} = {
    v => 1.1,
    summary => 'Complete from hash keys',
    args => {
        word  => { schema=>[str=>{default=>''}], pos=>0, req=>1 },
        hash  => { schema=>['hash*'=>{}], req=>1 },
        ci    => { schema=>['bool'] },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_hash_key {
    my %args  = @_;
    my $hash  = $args{hash} or die "Please specify hash";
    my $word  = $args{word} // "";
    my $ci    = $args{ci} // $Complete::Setting::OPT_CI;

    complete_array_elem(word=>$word, array=>[keys %$hash], ci=>$ci);
}

$SPEC{combine_answers} = {
    v => 1.1,
    summary => 'Given two or more answers, combine them into one',
    description => <<'_',

This function is useful if you want to provide a completion answer that is
gathered from multiple sources. For example, say you are providing completion
for the Perl tool `cpanm`, which accepts a filename (a tarball like `*.tar.gz`),
a directory, or a module name. You can do something like this:

    combine_answers(
        complete_file(word=>$word, ci=>1),
        complete_module(word=>$word, ci=>1),
    );

If a completion answer has a metadata `final` set to true, then that answer is
used as the final answer without any combining with the other answers.

_
    args => {
        answers => {
            schema => [
                'array*' => {
                    of => ['any*', of=>['hash*','array*']], # XXX answer_t
                    min_len => 1,
                },
            ],
            req => 1,
            pos => 0,
            greedy => 1,
        },
    },
    args_as => 'array',
    result_naked => 1,
    result => {
        schema => 'hash*',
        description => <<'_',

Return a combined completion answer. Words from each input answer will be
combined, order preserved and duplicates removed. The other keys from each
answer will be merged.

_
    },
};
sub combine_answers {
    require List::Util;

    return undef unless @_;
    return $_[0] if @_ < 2;

    my $final = {words=>[]};
    my $encounter_hash;
    my $add_words = sub {
        my $words = shift;
        for my $entry (@$words) {
            push @{ $final->{words} }, $entry
                unless List::Util::first(
                    sub {
                        (ref($entry) ? $entry->{word} : $entry)
                            eq
                                (ref($_) ? $_->{word} : $_)
                            }, @{ $final->{words} }
                        );
        }
    };

  ANSWER:
    for my $ans (@_) {
        if (ref($ans) eq 'ARRAY') {
            $add_words->($ans);
        } elsif (ref($ans) eq 'HASH') {
            $encounter_hash++;

            if ($ans->{final}) {
                $final = $ans;
                last ANSWER;
            }

            $add_words->($ans->{words} // []);
            for (keys %$ans) {
                if ($_ eq 'words') {
                    next;
                } elsif ($_ eq 'static') {
                    if (exists $final->{$_}) {
                        $final->{$_} &&= $ans->{$_};
                    } else {
                        $final->{$_} = $ans->{$_};
                    }
                } else {
                    $final->{$_} = $ans->{$_};
                }
            }
        }
    }

    # re-sort final words
    if ($final->{words}) {
        $final->{words} = [
            sort {
                (ref($a) ? $a->{word} : $a) cmp
                    (ref($b) ? $b->{word} : $b);
            }
                @{ $final->{words} }];
    }

    $encounter_hash ? $final : $final->{words};
}

1;
# ABSTRACT:

=for Pod::Coverage ^(complete_array)$

=head1 DESCRIPTION


=head1 SEE ALSO

L<Complete>

If you want to do bash tab completion with Perl, take a look at
L<Complete::Bash> or L<Getopt::Long::Complete> or L<Perinci::CmdLine>.

Other C<Complete::*> modules.
