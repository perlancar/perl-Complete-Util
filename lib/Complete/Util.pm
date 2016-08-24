package Complete::Util;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use Complete::Common qw(:all);

use Exporter qw(import);
our @EXPORT_OK = qw(
                       hashify_answer
                       arrayify_answer
                       combine_answers
                       complete_array_elem
                       complete_hash_key
                       complete_comma_sep
               );

our %SPEC;

our $COMPLETE_UTIL_TRACE = $ENV{COMPLETE_UTIL_TRACE} // 0;

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
    args_as => 'array',
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
    args_as => 'array',
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

our $code_editdist;

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

my %complete_array_elem_args = (
    %arg_word,
    array       => {
        schema => ['array*'=>{of=>'str*'}],
        req => 1,
    },
    exclude     => {
        schema => ['array*'],
    },
    replace_map => {
        schema => ['hash*', each_value=>['array*', of=>'str*']],
        description => <<'_',

You can supply correction entries in this option. An example is when array if
`['mount','unmount']` and `umount` is a popular "typo" for `unmount`. When
someone already types `um` it cannot be completed into anything (even the
current fuzzy mode will return *both* so it cannot complete immediately).

One solution is to add replace_map `{'unmount'=>['umount']}`. This way, `umount`
will be regarded the same as `unmount` and when user types `um` it can be
completed unambiguously into `unmount`.

_
        tags => ['experimental'],
    },
);

$SPEC{complete_array_elem} = {
    v => 1.1,
    summary => 'Complete from array',
    description => <<'_',

Try to find completion from an array of strings. Will attempt several methods,
from the cheapest and most discriminating to the most expensive and least
discriminating: normal string prefix matching, word-mode matching (see
`Complete::Common::OPT_WORD_MODE` for more details), char-mode matching (see
`Complete::Common::OPT_CHAR_MODE` for more details), and fuzzy matching (see
`Complete::Common::OPT_FUZZY` for more details).

Will sort the resulting completion list, so you don't have to presort the array.

_
    args => {
        %complete_array_elem_args,
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_array_elem {
    my %args  = @_;

    my $array0    = $args{array} or die "Please specify array";
    my $word      = $args{word} // "";

    my $ci          = $Complete::Common::OPT_CI;
    my $map_case    = $Complete::Common::OPT_MAP_CASE;
    my $word_mode   = $Complete::Common::OPT_WORD_MODE;
    my $char_mode   = $Complete::Common::OPT_CHAR_MODE;
    my $fuzzy       = $Complete::Common::OPT_FUZZY;

    return [] unless @$array0;

    # normalize
    my $wordn = $ci ? uc($word) : $word; $wordn =~ s/_/-/g if $map_case;

    my $excluden;
    if ($args{exclude}) {
        $excluden = {};
        for my $el (@{$args{exclude}}) {
            my $eln = $ci ? uc($el) : $el; $eln =~ s/_/-/g if $map_case;
            $excluden->{$eln} //= 1;
        }
    }

    my $rmapn;
    my $rev_rmapn; # to replace back to the original words back in the result
    if (my $rmap = $args{replace_map}) {
        $rmapn = {};
        $rev_rmapn = {};
        for my $k (keys %$rmap) {
            my $kn = $ci ? uc($k) : $k; $kn =~ s/_/-/g if $map_case;
            my @vn;
            for my $v (@{ $rmap->{$k} }) {
                my $vn = $ci ? uc($v) : $v; $vn =~ s/_/-/g if $map_case;
                push @vn, $vn;
                $rev_rmapn->{$vn} //= $k;
            }
            $rmapn->{$kn} = \@vn;
        }
    }

    my @words; # the answer
    my @array ;  # original array + rmap entries
    my @arrayn;  # case- & map-case-normalized form of $array + rmap entries

    # normal string prefix matching. we also fill @array & @arrayn here (which
    # will be used again in word-mode, fuzzy, and char-mode matching) so we
    # don't have to calculate again.
    $log->tracef("[computil] Trying normal string-prefix matching ...") if $COMPLETE_UTIL_TRACE;
    for my $el (@$array0) {
        my $eln = $ci ? uc($el) : $el; $eln =~ s/_/-/g if $map_case;
        next if $excluden && $excluden->{$eln};
        push @array , $el;
        push @arrayn, $eln;
        push @words , $el if 0==index($eln, $wordn);
        if ($rmapn && $rmapn->{$eln}) {
            for my $vn (@{ $rmapn->{$eln} }) {
                push @array , $el;
                push @arrayn, $vn;
                # we add the normalized form, because we'll just revert it back
                # to the original word in the final result
                push @words , $vn if 0==index($vn, $wordn);
            }
        }
    }
    $log->tracef("[computil] Result from normal string-prefix matching: %s", \@words) if @words && $COMPLETE_UTIL_TRACE;

    # word-mode matching
    {
        last unless $word_mode && !@words;
        my @split_wordn = $wordn =~ /(\w+)/g;
        unshift @split_wordn, '' if $wordn =~ /\A\W/;
        last unless @split_wordn > 1;
        my $re = '\A';
        for my $i (0..$#split_wordn) {
            $re .= '(?:\W+\w+)*\W+' if $i;
            $re .= quotemeta($split_wordn[$i]).'\w*';
        }
        $re = qr/$re/;
        $log->tracef("[computil] Trying word-mode matching (re=%s) ...", $re) if $COMPLETE_UTIL_TRACE;

        for my $i (0..$#array) {
            my $match;
            {
                if ($arrayn[$i] =~ $re) {
                    $match++;
                    last;
                }
                # try splitting CamelCase into Camel-Case
                my $tmp = $array[$i];
                if ($tmp =~ s/([a-z0-9_])([A-Z])/$1-$2/g) {
                    $tmp = uc($tmp) if $ci; $tmp =~ s/_/-/g if $map_case; # normalize again
                    if ($tmp =~ $re) {
                        $match++;
                        last;
                    }
                }
            }
            next unless $match;
            push @words, $array[$i];
        }
        $log->tracef("[computil] Result from word-mode matching: %s", \@words) if @words && $COMPLETE_UTIL_TRACE;
    }

    # char-mode matching
    if ($char_mode && !@words && length($wordn) && length($wordn) <= 7) {
        my $re = join(".*", map {quotemeta} split(//, $wordn));
        $re = qr/$re/;
        $log->tracef("[computil] Trying char-mode matching (re=%s) ...", $re) if $COMPLETE_UTIL_TRACE;
        for my $i (0..$#array) {
            push @words, $array[$i] if $arrayn[$i] =~ $re;
        }
        $log->tracef("[computil] Result from char-mode matching: %s", \@words) if @words && $COMPLETE_UTIL_TRACE;
    }

    # fuzzy matching
    if ($fuzzy && !@words) {
        $log->tracef("[computil] Trying fuzzy matching ...") if $COMPLETE_UTIL_TRACE;
        $code_editdist //= do {
            if (($ENV{COMPLETE_UTIL_LEVENSHTEIN} // '') eq 'xs') {
                require Text::Levenshtein::XS;
                \&Text::Levenshtein::XS::distance;
            } elsif (($ENV{COMPLETE_UTIL_LEVENSHTEIN} // '') eq 'pp') {
                \&__editdist;
            } elsif (eval { require Text::Levenshtein::XS; 1 }) {
                \&Text::Levenshtein::XS::distance;
            } else {
                \&__editdist;
            }
        };

        my $factor = 1.3;
        my $x = -1;
        my $y = 1;

        my %editdists;
      ELEM:
        for my $i (0..$#array) {
            my $eln = $arrayn[$i];

            for my $l (length($wordn)-$y .. length($wordn)+$y) {
                next if $l <= 0;
                my $chopped = substr($eln, 0, $l);
                my $d;
                unless (defined $editdists{$chopped}) {
                    $d = $code_editdist->($wordn, $chopped);
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
                push @words, $array[$i];
                next ELEM;
            }
        }
        $log->tracef("[computil] Result from fuzzy matching: %s", \@words) if @words && $COMPLETE_UTIL_TRACE;
    }

    # replace back the words from replace_map
    if ($rmapn && @words) {
        my @wordsn;
        for my $el (@words) {
            my $eln = $ci ? uc($el) : $el; $eln =~ s/_/-/g if $map_case;
            push @wordsn, $eln;
        }
        for my $i (0..$#words) {
            if (my $w = $rev_rmapn->{$wordsn[$i]}) {
                $words[$i] = $w;
            }
        }
    }

    return $ci ? [sort {lc($a) cmp lc($b)} @words] : [sort @words];
}

$SPEC{complete_hash_key} = {
    v => 1.1,
    summary => 'Complete from hash keys',
    args => {
        %arg_word,
        hash      => { schema=>['hash*'=>{}], req=>1 },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_hash_key {
    my %args  = @_;
    my $hash      = $args{hash} or die "Please specify hash";
    my $word      = $args{word} // "";

    complete_array_elem(
        word=>$word, array=>[sort keys %$hash],
    );
}

my %complete_comma_sep_args = (
    %complete_array_elem_args,
    sep => {
        schema  => 'str*',
        default => ',',
    },
    uniq => {
        summary => 'Whether list contains unique elements',
        schema => ['str*', is=>1],
    },
);
$complete_comma_sep_args{elems} = delete $complete_comma_sep_args{array};

$SPEC{complete_comma_sep} = {
    v => 1.1,
    summary => 'Complete a comma-separated list string',
    args => {
        %complete_comma_sep_args,
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_comma_sep {
    my %args  = @_;
    my $word      = delete $args{word} // "";
    my $sep       = delete $args{sep} // ',';
    my $elems     = delete $args{elems} or die "Please specify elems";
    my $uniq      = delete $args{uniq};

    my $ci = $Complete::Common::OPT_CI;

    my @mentioned_elems = split /\Q$sep\E/, $word, -1;
    my $cae_word = @mentioned_elems ? pop(@mentioned_elems) : '';

    my @unmentioned_elems;
    {
        last unless $uniq;
        my %mem;
        for (@mentioned_elems) {
            if ($ci) { $mem{lc $_}++ } else { $mem{$_}++ }
        }
        for (@$elems) {
            push @unmentioned_elems, $_ unless ($ci ? $mem{lc $_} : $mem{$_});
        }
    }

    my $cae_res = complete_array_elem(
        %args,
        word  => $cae_word,
        array => ($uniq ? \@unmentioned_elems : $elems),
    );

    my $prefix = join($sep, @mentioned_elems);
    $prefix .= $sep if @mentioned_elems;
    $cae_res = [map { "$prefix$_" } @$cae_res];

    # add trailing comma for convenience, where appropriate
    {
        last unless @$cae_res == 1;
        last if $uniq && @unmentioned_elems <= 1;
        $cae_res->[0] .= $sep;
    }
    $cae_res;
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

=head1 DESCRIPTION


=head1 ENVIRONMENT

=head2 COMPLETE_UTIL_TRACE => bool

If set to true, will display more log statements for debugging.

=head2 COMPLETE_UTIL_LEVENSHTEIN => str ('pp'|'xs')

Can be used to force which levenshtein implementation to use. The default is to
use XS version from L<Text::Levenshtein::XS> if that module is installed,
otherwise fallback to the included PP implementation (which is about 1-2 orders
of magnitude slower).


=head1 SEE ALSO

L<Complete>

If you want to do bash tab completion with Perl, take a look at
L<Complete::Bash> or L<Getopt::Long::Complete> or L<Perinci::CmdLine>.

Other C<Complete::*> modules.

L<Bencher::Scenarios::CompleteUtil>
