package Complete::Util;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Complete::Common qw(:all);
use Exporter qw(import);

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw(
                       hashify_answer
                       arrayify_answer
                       combine_answers
                       modify_answer
                       ununiquify_answer
                       answer_has_entries
                       answer_num_entries
                       complete_array_elem
                       complete_hash_key
                       complete_hash_value
                       complete_comma_sep
                       complete_comma_sep_pair
                       get_answer_words
                       get_answer_summaries
               );

our %SPEC;

our $COMPLETE_UTIL_TRACE = $ENV{COMPLETE_UTIL_TRACE} // 0;

our %arg0_answer = (
    answer => {
        summary => 'Completion answer structure',
        schema  => ['any*' => of => ['array*','hash*']],
        req => 1,
        pos => 0,
    },
);

$SPEC{':package'} = {
    v => 1.1,
    summary => 'General completion routine',
    description => <<'MARKDOWN',

This package provides some generic completion routines that follow the
<pm:Complete> convention. (If you are looking for bash/shell tab completion
routines, take a look at L</"SEE ALSO">.) The main routine is
`complete_array_elem` which tries to complete a word using choices from elements
of supplied array. For example:

    complete_array_elem(word => "a", array => ["apple", "apricot", "banana"]);

The routine will first try a simple substring prefix matching. If that fails,
will try some other methods like word-mode, character-mode, or fuzzy matching.
These methods can be disabled using settings.

There are other utility routines e.g. for converting completion answer structure
from hash to array/array to hash, combine or modify answer, etc. These routines
are usually used by the other more specific or higher-level completion modules.

MARKDOWN
};

$SPEC{hashify_answer} = {
    v => 1.1,
    summary => 'Make sure we return completion answer in hash form',
    description => <<'MARKDOWN',

This function accepts a hash or an array. If it receives an array, will convert
the array into `{words=>$ary}' first to make sure the completion answer is in
hash form.

Then will add keys from `meta` to the hash.

MARKDOWN
    args => {
        %arg0_answer,
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
    return unless defined $ans;
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
    description => <<'MARKDOWN',

This is the reverse of `hashify_answer`. It accepts a hash or an array. If it
receives a hash, will return its `words` key.

MARKDOWN
    args => {
        %arg0_answer,
    },
    args_as => 'array',
    result_naked => 1,
    result => {
        schema => 'array*',
    },
};
sub arrayify_answer {
    my $ans = shift;
    return unless defined $ans;
    if (ref($ans) eq 'HASH') {
        $ans = $ans->{words};
    }
    $ans;
}

$SPEC{get_answer_words} = {
    v => 1.1,
    summary => 'Extract just the words from answer structure',
    description => <<'MARKDOWN',

This routine accepts a hash or an array answer structure. It then returns an
arrayref containing just the words from each answer entry. If the answer is
undef, it returns an empty arrayref.

See also: `get_answer_summaries()`.

MARKDOWN
    args => {
        %arg0_answer,
    },
    args_as => 'array',
    result_naked => 1,
    result => {
        schema => 'array*',
    },
};
sub get_answer_words {
    my $ans = shift;
    return [] unless defined $ans;
    if (ref($ans) eq 'HASH') {
        $ans = $ans->{words};
    }
    my @words;
    for (@$ans) { push @words, ref($_) eq 'HASH' ? $_->{word} : $_ }
    \@words;
}

$SPEC{get_answer_summaries} = {
    v => 1.1,
    summary => 'Extract just the entry summaries from answer structure',
    description => <<'MARKDOWN',

This routine accepts a hash or an array answer structure. It then returns an
arrayref containing just the summaries from each answer entry. If the answer is
undef, it returns an empty arrayref.

See also: `get_answer_words()`.

MARKDOWN
    args => {
        %arg0_answer,
    },
    args_as => 'array',
    result_naked => 1,
    result => {
        schema => 'array*',
    },
};
sub get_answer_summaries {
    my $ans = shift;
    return [] unless defined $ans;
    if (ref($ans) eq 'HASH') {
        $ans = $ans->{words};
    }
    my @summaries;
    for (@$ans) { push @summaries, ref($_) eq 'HASH' ? $_->{summary} : undef }
    \@summaries;
}

$SPEC{answer_num_entries} = {
    v => 1.1,
    summary => 'Get the number of entries in an answer',
    description => <<'MARKDOWN',

It is equivalent to:

    ref $answer eq 'ARRAY' ? (@$answer // 0) : (@{$answer->{words}} // 0);

MARKDOWN
    args => {
        %arg0_answer,
    },
    args_as => 'array',
    result_naked => 1,
    result => {
        schema => 'int*',
    },
};
sub answer_num_entries {
    my $ans = shift;
    return unless defined $ans;
    return ref($ans) eq 'HASH' ? (@{$ans->{words} // []} // 0) : (@$ans // 0);
}

$SPEC{answer_has_entries} = {
    v => 1.1,
    summary => 'Check if answer has entries',
    description => <<'MARKDOWN',

It is equivalent to:

    ref $answer eq 'ARRAY' ? (@$answer ? 1:0) : (@{$answer->{words}} ? 1:0);

MARKDOWN
    args => {
        %arg0_answer,
    },
    args_as => 'array',
    result_naked => 1,
    result => {
        schema => 'int*',
    },
};
sub answer_has_entries {
    my $ans = shift;
    return unless defined $ans;
    return ref($ans) eq 'HASH' ? (@{$ans->{words} // []} ? 1:0) : (@$ans ? 1:0);
}

sub __min(@) { ## no critic: Subroutines::ProhibitSubroutinePrototypes
    my $m = $_[0];
    for (@_) {
        $m = $_ if $_ < $m;
    }
    $m;
}

our $code_editdist;
our $editdist_flex;

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
        pos => 1,
        slurpy => 1,
    },
    summaries => {
        schema => ['array*'=>{of=>'str*'}],
    },
    exclude     => {
        schema => ['array*'],
    },
    replace_map => {
        schema => ['hash*', each_value=>['array*', of=>'str*']],
        description => <<'MARKDOWN',

You can supply correction entries in this option. An example is when array if
`['mount','unmount']` and `umount` is a popular "typo" for `unmount`. When
someone already types `um` it cannot be completed into anything (even the
current fuzzy mode will return *both* so it cannot complete immediately).

One solution is to add replace_map `{'unmount'=>['umount']}`. This way, `umount`
will be regarded the same as `unmount` and when user types `um` it can be
completed unambiguously into `unmount`.

MARKDOWN
        tags => ['experimental'],
    },
);

$SPEC{complete_array_elem} = {
    v => 1.1,
    summary => 'Complete from array',
    description => <<'MARKDOWN',

Try to find completion from an array of strings. Will attempt several methods,
from the cheapest and most discriminating to the most expensive and least
discriminating.

First method is normal/exact string prefix matching (either case-sensitive or
insensitive depending on the `$Complete::Common::OPT_CI` variable or the
`COMPLETE_OPT_CI` environment variable). If at least one match is found, return
result. Else, proceed to the next method.

Word-mode matching (can be disabled by setting
`$Complete::Common::OPT_WORD_MODE` or `COMPLETE_OPT_WORD_MODE` environment
varialbe to false). Word-mode matching is described in <pm:Complete::Common>. If
at least one match is found, return result. Else, proceed to the next method.

Prefix char-mode matching (can be disabled by settings
`$Complete::Common::OPT_CHAR_MODE` or `COMPLETE_OPT_CHAR_MODE` environment
variable to false). Prefix char-mode matching is just like char-mode matching
(see next paragraph) except the first character must match. If at least one
match is found, return result. Else, proceed to the next method.

Char-mode matching (can be disabled by settings
`$Complete::Common::OPT_CHAR_MODE` or `COMPLETE_OPT_CHAR_MODE` environment
variable to false). Char-mode matching is described in <pm:Complete::Common>. If
at least one match is found, return result. Else, proceed to the next method.

Fuzzy matching (can be disabled by setting `$Complete::Common::OPT_FUZZY` or
`COMPLETE_OPT_FUZZY` to false). Fuzzy matching is described in
<pm:Complete::Common>. If at least one match is found, return result. Else,
return empty string.

Will sort the resulting completion list, so you don't have to presort the array.

MARKDOWN
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

    my $array0    = delete $args{array} or die "Please specify array";
    my $summaries = delete $args{summaries};
    my $word      = delete($args{word}) // "";
    my $exclude   = delete $args{exclude};
    my $replace_map = delete $args{replace_map};
    die "complete_array_elem(): Unknown argument(s): ".join(", ", keys %args)
        if keys %args;

    my $ci          = $Complete::Common::OPT_CI;
    my $map_case    = $Complete::Common::OPT_MAP_CASE;
    my $word_mode   = $Complete::Common::OPT_WORD_MODE;
    my $char_mode   = $Complete::Common::OPT_CHAR_MODE;
    my $fuzzy       = $Complete::Common::OPT_FUZZY;

    log_trace("[computil] entering complete_array_elem(), word=<%s>", $word)
        if $COMPLETE_UTIL_TRACE;

    my $res;

    unless (@$array0) {
        $res = []; goto RETURN_RES;
    }

    # normalize
    my $wordn = $ci ? uc($word) : $word; $wordn =~ s/_/-/g if $map_case;

    my $excluden;
    if ($exclude) {
        $excluden = {};
        for my $el (@{$exclude}) {
            my $eln = $ci ? uc($el) : $el; $eln =~ s/_/-/g if $map_case;
            $excluden->{$eln} //= 1;
        }
    }

    my $rmapn;
    my $rev_rmapn; # to replace back to the original words back in the result
    if ($replace_map) {
        $rmapn = {};
        $rev_rmapn = {};
        for my $k (keys %$replace_map) {
            my $kn = $ci ? uc($k) : $k; $kn =~ s/_/-/g if $map_case;
            my @vn;
            for my $v (@{ $replace_map->{$k} }) {
                my $vn = $ci ? uc($v) : $v; $vn =~ s/_/-/g if $map_case;
                push @vn, $vn;
                $rev_rmapn->{$vn} //= $k;
            }
            $rmapn->{$kn} = \@vn;
        }
    }

    my @words;      # the answer
    my @wordsumms;  # summaries for each item in @words
    my @array ;     # original array + rmap entries
    my @arrayn;     # case- & map-case-normalized form of $array + rmap entries
    my @arraysumms; # summaries for each item in @array (or @arrayn)

    # normal string prefix matching. we also fill @array & @arrayn here (which
    # will be used again in word-mode, fuzzy, and char-mode matching) so we
    # don't have to calculate again.
    log_trace("[computil] Trying normal string-prefix matching ...") if $COMPLETE_UTIL_TRACE;
    for my $i (0..$#{$array0}) {
        my $el = $array0->[$i];
        my $eln = $ci ? uc($el) : $el; $eln =~ s/_/-/g if $map_case;
        next if $excluden && $excluden->{$eln};
        push @array , $el;
        push @arrayn, $eln;
        push @arraysumms, $summaries->[$i] if $summaries;
        if (0==index($eln, $wordn)) {
            push @words, $el;
            push @wordsumms, $summaries->[$i] if $summaries;
        }
        if ($rmapn && $rmapn->{$eln}) {
            for my $vn (@{ $rmapn->{$eln} }) {
                push @array , $el;
                push @arrayn, $vn;
                # we add the normalized form, because we'll just revert it back
                # to the original word in the final result
                if (0==index($vn, $wordn)) {
                    push @words, $vn;
                    push @wordsumms, $summaries->[$i] if $summaries;
                }
            }
        }
    }
    log_trace("[computil] Result from normal string-prefix matching: %s", \@words) if @words && $COMPLETE_UTIL_TRACE;

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
        log_trace("[computil] Trying word-mode matching (re=%s) ...", $re) if $COMPLETE_UTIL_TRACE;

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
            push @wordsumms, $arraysumms[$i] if $summaries;
        }
        log_trace("[computil] Result from word-mode matching: %s", \@words) if @words && $COMPLETE_UTIL_TRACE;
    }

    # prefix char-mode matching
    if ($char_mode && !@words && length($wordn) && length($wordn) <= 7) {
        my $re = join(".*", map {quotemeta} split(//, $wordn));
        $re = qr/\A$re/;
        log_trace("[computil] Trying prefix char-mode matching (re=%s) ...", $re) if $COMPLETE_UTIL_TRACE;
        for my $i (0..$#array) {
            if ($arrayn[$i] =~ $re) {
                push @words, $array[$i];
                push @wordsumms, $arraysumms[$i] if $summaries;
            }
        }
        log_trace("[computil] Result from prefix char-mode matching: %s", \@words) if @words && $COMPLETE_UTIL_TRACE;
    }

    # char-mode matching
    if ($char_mode && !@words && length($wordn) && length($wordn) <= 7) {
        my $re = join(".*", map {quotemeta} split(//, $wordn));
        $re = qr/$re/;
        log_trace("[computil] Trying char-mode matching (re=%s) ...", $re) if $COMPLETE_UTIL_TRACE;
        for my $i (0..$#array) {
            if ($arrayn[$i] =~ $re) {
                push @words, $array[$i];
                push @wordsumms, $arraysumms[$i] if $summaries;
            }
        }
        log_trace("[computil] Result from char-mode matching: %s", \@words) if @words && $COMPLETE_UTIL_TRACE;
    }

    # fuzzy matching
    if ($fuzzy && !@words) {
        log_trace("[computil] Trying fuzzy matching ...") if $COMPLETE_UTIL_TRACE;
        $code_editdist //= do {
            my $env = $ENV{COMPLETE_UTIL_LEVENSHTEIN} // '';
            if ($env eq 'xs') {
                require Text::Levenshtein::XS;
                $editdist_flex = 0;
                \&Text::Levenshtein::XS::distance;
            } elsif ($env eq 'flexible') {
                require Text::Levenshtein::Flexible;
                $editdist_flex = 1;
                \&Text::Levenshtein::Flexible::levenshtein_l;
            } elsif ($env eq 'pp') {
                $editdist_flex = 0;
                \&__editdist;
            } elsif (eval { require Text::Levenshtein::Flexible; 1 }) {
                $editdist_flex = 1;
                \&Text::Levenshtein::Flexible::levenshtein_l;
            } else {
                $editdist_flex = 0;
                \&__editdist;
            }
        };

        my $factor = 1.3;
        my $x = -1;
        my $y = 1;

        # note: we cannot use Text::Levenshtein::Flexible::levenshtein_l_all()
        # because we perform distance calculation on the normalized array but we
        # want to get the original array elements

        my %editdists;
      ELEM:
        for my $i (0..$#array) {
            my $eln = $arrayn[$i];

            for my $l (length($wordn)-$y .. length($wordn)+$y) {
                next if $l <= 0;
                my $chopped = substr($eln, 0, $l);
                my $maxd = __min(
                    __min(length($chopped), length($word))/$factor,
                    $fuzzy,
                );
                my $d;
                unless (defined $editdists{$chopped}) {
                    if ($editdist_flex) {
                        $d = $code_editdist->($wordn, $chopped, $maxd);
                        next ELEM unless defined $d;
                    } else {
                        $d = $code_editdist->($wordn, $chopped);
                    }
                    $editdists{$chopped} = $d;
                } else {
                    $d = $editdists{$chopped};
                }
                #say "D: d($word,$chopped)=$d (maxd=$maxd)";
                next unless $d <= $maxd;
                push @words, $array[$i];
                push @wordsumms, $arraysumms[$i] if $summaries;
                next ELEM;
            }
        }
        log_trace("[computil] Result from fuzzy matching: %s", \@words) if @words && $COMPLETE_UTIL_TRACE;
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

    # sort results and insert summaries
    $res = [
        map {
            $summaries ?
                {word=>$words[$_], summary=>$wordsumms[$_]} :
                $words[$_]
            }
            sort {
                $ci ?
                    lc($words[$a]) cmp lc($words[$b]) :
                    $words[$a]     cmp $words[$b] }
            0 .. $#words
        ];

  RETURN_RES:
    log_trace("[computil] leaving complete_array_elem(), res=%s", $res)
        if $COMPLETE_UTIL_TRACE;
    $res;
}

$SPEC{complete_hash_key} = {
    v => 1.1,
    summary => 'Complete from hash keys',
    args => {
        %arg_word,
        hash      => { schema=>['hash*'=>{}], req=>1 },
        summaries => { schema=>['hash*'=>{}] },
        summaries_from_hash_values => { schema=>'true*' },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
    args_rels => {
        choose_one => ['summaries', 'summaries_from_hash_values'],
    },
};
sub complete_hash_key {
    my %args  = @_;
    my $hash      = delete $args{hash} or die "Please specify hash";
    my $word      = delete($args{word}) // "";
    my $summaries = delete $args{summaries};
    my $summaries_from_hash_values = delete $args{summaries_from_hash_values};
    die "complete_hash_key(): Unknown argument(s): ".join(", ", keys %args)
        if keys %args;

    my @keys = keys %$hash;
    my @summaries;
    my $has_summary;
    if ($summaries) {
        $has_summary++;
        for (@keys) { push @summaries, $summaries->{$_} }
    } elsif ($summaries_from_hash_values) {
        $has_summary++;
        for (@keys) { push @summaries, $hash->{$_} }
    }

    complete_array_elem(
        word=>$word, array=>\@keys,
        (summaries=>\@summaries) x !!$has_summary,
    );
}


$SPEC{complete_hash_value} = {
    v => 1.1,
    summary => 'Complete from hash values',
    args => {
        %arg_word,
        hash      => { schema=>['hash*'=>{}], req=>1 },
        summaries => { schema=>['hash*'=>{}] },
        summaries_from_hash_keys => { schema=>'true*' },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
    args_rels => {
        choose_one => ['summaries', 'summaries_from_hash_keys'],
    },
};
sub complete_hash_value {
    my %args  = @_;
    my $hash      = delete $args{hash} or die "Please specify hash";
    my $word      = delete($args{word}) // "";
    my $summaries = delete $args{summaries};
    my $summaries_from_hash_keys = delete $args{summaries_from_hash_keys};
    die "complete_hash_values(): Unknown argument(s): ".join(", ", keys %args)
        if keys %args;

    my @keys   = keys %$hash;
    my @values = map { "$hash->{$_}" } @keys;
    my @summaries;
    my $has_summary;
    if ($summaries) {
        $has_summary++;
        for (@values) { push @summaries, $summaries->{$_} }
    } elsif ($summaries_from_hash_keys) {
        $has_summary++;
        @summaries = @keys;
    }

    complete_array_elem(
        word=>$word, array=>\@values,
        (summaries=>\@summaries) x !!$has_summary,
    );
}

my %complete_comma_sep_args = (
    %complete_array_elem_args,
    sep => {
        schema  => 'str*',
        default => ',',
    },
    uniq => {
        summary => 'Whether list should contain unique elements',
        description => <<'MARKDOWN',

When this option is set to true, if the formed list in the current word already
contains an element, the element will not be offered again as completion answer.
For example, if `elems` is `[1,2,3,4]` and `word` is `2,3,` then without `uniq`
set to true the completion answer is:

    2,3,1
    2,3,2
    2,3,3
    2,3,4

but with `uniq` set to true, the completion answer becomes:

    2,3,1
    2,3,4

See also the `remaining` option for a more general mechanism of offering fewer
elements.

MARKDOWN
        schema => ['bool*', is=>1],
    },
    remaining => {
        schema => ['code*'],
        summary => 'What elements should remain for completion',
        description => <<'MARKDOWN',

This is a more general mechanism if the `uniq` option does not suffice. Suppose
you are offering completion for sorting fields. The elements are field names as
well as field names prefixed with dash (`-`) to mean sorting with a reverse
order. So for example `elems` is `["name","-name","age","-age"]`. When current
word is `name`, it doesn't make sense to offer `name` nor `-name` again as the
next sorting field. So we can set `remaining` to this code:

    sub {
        my ($seen_elems, $elems) = @_;

        my %seen;
        for (@$seen_elems) {
            (my $nodash = $_) =~ s/^-//;
            $seen{$nodash}++;
        }

        my @remaining;
        for (@$elems) {
            (my $nodash = $_) =~ s/^-//;
            push @remaining, $_ unless $seen{$nodash};
        }

        \@remaining;
    }

As you can see above, the code is given `$seen_elems` and `$elems` as arguments
and is expected to return remaining elements to offer.

MARKDOWN
        tags => ['hidden-cli'],
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
    my $summaries = delete $args{summaries};
    my $uniq      = delete $args{uniq};
    my $remaining = delete $args{remaining};
    my $exclude     = delete $args{exclude};
    my $replace_map = delete $args{replace_map};
    die "complete_comma_sep(): Unknown argument(s): ".join(", ", keys %args)
        if keys %args;

    my $ci = $Complete::Common::OPT_CI;

    my %summaries_for; # key=elem val=summary
  GEN_SUMMARIES_HASH:
    {
        last unless $summaries;
        for my $i (0 .. $#{$elems}) {
            my $elem0 = $elems->[$i];
            my $summary = $summaries->[$i];
            my $elem = $ci ? lc($elem0) : $elem0;
            if (exists $summaries_for{$elem}) {
                log_warn "Non-unique value '$elem', using only the first summary for it";
                next;
            }
            $summaries_for{$elem} = $summary;
        }
    } # GEN_SUMMARIES_HASH

    my @mentioned_elems = split /\Q$sep\E/, $word, -1;
    my $cae_word = @mentioned_elems ? pop(@mentioned_elems) : ''; # cae=complete_array_elem

    my $remaining_elems;
    if ($remaining) {
        $remaining_elems = $remaining->(\@mentioned_elems, $elems);
    } elsif ($uniq) {
        my %mem;
        $remaining_elems = [];
        for (@mentioned_elems) {
            if ($ci) { $mem{lc $_}++ } else { $mem{$_}++ }
        }
        for (@$elems) {
            push @$remaining_elems, $_ unless ($ci ? $mem{lc $_} : $mem{$_});
        }
    } else {
        $remaining_elems = $elems;
    }

    my $cae_res = complete_array_elem(
        word  => $cae_word,
        array => $remaining_elems,
        exclude => $exclude,
        replace_map => $replace_map,
        ($summaries ? (summaries=>[map {$summaries_for{ $ci ? lc($_):$_ }} @$remaining_elems]) : ()),
    );

    my $prefix = join($sep, @mentioned_elems);
    $prefix .= $sep if @mentioned_elems;
    $cae_res = [map { ref $_ eq 'HASH' ? { %$_, word=>"$prefix$_->{word}" } : "$prefix$_" } @$cae_res];

    # add trailing comma for convenience, where appropriate
    {
        last unless @$cae_res == 1;
        last if @$remaining_elems <= 1;
        $cae_res = [{word=>$cae_res->[0]}] unless ref $cae_res->[0] eq 'HASH';
        $cae_res = [{word=>"$cae_res->[0]{word}$sep", (defined $cae_res->[0]{summary} ? (summary=>$cae_res->[0]{summary}) : ()), is_partial=>1}];
    }
    $cae_res;
}

$SPEC{complete_comma_sep_pair} = {
    v => 1.1,
    summary => 'Complete a comma-separated list of key-value pairs',
    args => {
        %arg_word,
        keys => {
            schema => ['array*', of=>'str*'],
            req => 1,
        },
        keys_summaries => {
            summary => 'Summary for each key',
            schema => ['array*', of=>'str*'],
        },
        complete_value => {
            summary => 'Code to supply possible values for a key',
            schema => 'code*',
            description => <<'MARKDOWN',

Code should accept hash arguments and will be given the arguments `word` (word
that is part of the value), and `key` (the key being evaluated) and is expected
to return a completion answer.

MARKDOWN
        },
        uniq => {
            summary => 'If set to true, then do not offer key that has been mentioned before in the word',
            schema => 'bool*',
            default => 1,
        },
        remaining_keys => {
            schema => ['code*'],
            summary => 'What keys should remain for completion',
            description => <<'MARKDOWN',

This is a more general mechanism if the `uniq` option does not suffice. Suppose
you are offering completion for arguments. Possible arguments are `foo`, `bar`,
`baz` but the `bar` and `baz` arguments are mutually exclusive. We can set
`remaining_keys` to this code:

    my %possible_args = {foo=>1, bar=>1, baz=>1};
    sub {
        my ($seen_elems, $elems) = @_;

        my %remaining = %possible_args;
        for (@$seen_elems) {
            delete $remaining{$_};
            delete $remaining{baz} if $_ eq 'bar';
            delete $remaining{bar} if $_ eq 'baz';
        }

        [keys %remaining];
    }

As you can see above, the code is given `$seen_elems` and `$elems` as arguments
and is expected to return remaining elements to offer.

MARKDOWN
        },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_comma_sep_pair {
    my %args  = @_;
    my $word           = delete $args{word} // "";
    my $sep            = delete $args{sep} // ',';
    my $keys           = delete $args{keys} or die "Please specify keys";
    my $keys_summaries = delete $args{keys_summaries};
    my $uniq           = delete $args{uniq} // 1;
    my $remaining_keys = delete $args{remaining_keys};
    my $complete_value = delete $args{complete_value};
    die "complete_comma_sep_pair(): Unknown argument(s): ".join(", ", keys %args)
        if keys %args;

    my $ci = $Complete::Common::OPT_CI;

    my %keys_summaries_for; # key=elem val=summary
  GEN_KEYS_SUMMARIES_HASH:
    {
        last unless $keys_summaries;
        for my $i (0 .. $#{$keys}) {
            my $key0 = $keys->[$i];
            my $summary = $keys_summaries->[$i];
            my $key = $ci ? lc($key0) : $key0;
            if (exists $keys_summaries_for{$key}) {
                log_warn "Non-unique key '$key', using only the first summary for it";
                next;
            }
            $keys_summaries_for{$key} = $summary;
        }
    } # GEN_KEYS_SUMMARIES_HASH

    my @mentioned_elems = split /\Q$sep\E/, $word, -1;
    my @mentioned_keys;
    for my $i (0..$#mentioned_elems) { push @mentioned_keys, $mentioned_elems[$i] if $i % 2 == 0 }

    if (@mentioned_elems == 0 || @mentioned_elems % 2 == 1) {

        # we should be completing keys
        my $cae_word = @mentioned_keys ? pop(@mentioned_keys) : ''; # cae=complete_array_elem

        my $remaining_elems;
        if ($remaining_keys) {
            $remaining_elems = $remaining_keys->(\@mentioned_keys, $keys);
        } elsif ($uniq) {
            my %mem;
            $remaining_elems = [];
            for (@mentioned_keys) {
                if ($ci) { $mem{lc $_}++ } else { $mem{$_}++ }
            }
            for (@$keys) {
                push @$remaining_elems, $_ unless ($ci ? $mem{lc $_} : $mem{$_});
            }
        } else {
            $remaining_elems = $keys;
        }

        my $cae_res = complete_array_elem(
            %args,
            word  => $cae_word,
            array => $remaining_elems,
            ($keys_summaries ? (summaries=>[map {$keys_summaries_for{ $ci ? lc($_):$_ }} @$remaining_elems]) : ()),
        );

        pop @mentioned_elems;
        my $prefix = join($sep, @mentioned_elems);
        $prefix .= $sep if @mentioned_elems;
        $cae_res = [map { ref $_ eq 'HASH' ? { %$_, word=>"$prefix$_->{word}" } : "$prefix$_" } @$cae_res];

        # add trailing comma for convenience, where appropriate
        {
            last unless @$cae_res == 1;
            last if @$remaining_elems <= 1;
            $cae_res = [{word=>$cae_res->[0]}] unless ref $cae_res->[0] eq 'HASH';
            $cae_res = [{word=>"$cae_res->[0]{word}$sep", (defined $cae_res->[0]{summary} ? (summary=>$cae_res->[0]{summary}) : ()), is_partial=>1}];
        }
        return $cae_res;

    } else {

        # we should be completing values

        return [] unless $complete_value;
        my $word = pop @mentioned_elems;
        my $res = $complete_value->(word=>$word, key=>$mentioned_keys[-1]);
        my $prefix = join($sep, @mentioned_elems);
        $prefix .= $sep if @mentioned_elems;
        modify_answer(answer=>$res, prefix=>$prefix);
    }
}

$SPEC{combine_answers} = {
    v => 1.1,
    summary => 'Given two or more answers, combine them into one',
    description => <<'MARKDOWN',

This function is useful if you want to provide a completion answer that is
gathered from multiple sources. For example, say you are providing completion
for the Perl tool <prog:cpanm>, which accepts a filename (a tarball like
`*.tar.gz`), a directory, or a module name. You can do something like this:

    combine_answers(
        complete_file(word=>$word),
        complete_module(word=>$word),
    );

But if a completion answer has a metadata `final` set to true, then that answer
is used as the final answer without any combining with the other answers.

MARKDOWN
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

    return unless @_;
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

    $encounter_hash ? $final : $final->{words};
}

$SPEC{modify_answer} = {
    v => 1.1,
    summary => 'Modify answer (add prefix/suffix, etc)',
    args => {
        answer => {
            schema => ['any*', of=>['hash*','array*']], # XXX answer_t
            req => 1,
            pos => 0,
        },
        suffix => {
            schema => 'str*',
        },
        prefix => {
            schema => 'str*',
        },
    },
    result_naked => 1,
    result => {
        schema => 'undef',
    },
};
sub modify_answer {
    my %args = @_;

    my $answer = delete $args{answer};
    my $words = ref($answer) eq 'HASH' ? $answer->{words} : $answer;
    my $prefix = delete $args{prefix};
    my $suffix = delete $args{suffix};
    die "modify_answer(): Unknown argument(s): ".join(", ", keys %args)
        if keys %args;

    if (defined $prefix) {
        for (@$words) {
            if (ref $_ eq 'HASH') {
                $_->{word} = "$prefix$_->{word}";
            } else {
                $_ = "$prefix$_";
            }
        }
    }
    if (defined $suffix) {
        for (@$words) {
            if (ref $_ eq 'HASH') {
                $_->{word} = "$_->{word}$suffix";
            } else {
                $_ = "$_$suffix";
            }
        }
    }
    $answer;
}

$SPEC{ununiquify_answer} = {
    v => 1.1,
    summary => 'If answer contains only one item, make it two',
    description => <<'MARKDOWN',

For example, if answer is `["a"]`, then will make answer become `["a","a "]`.
This will prevent shell from automatically adding space.

MARKDOWN
    args => {
        answer => {
            schema => ['any*', of=>['hash*','array*']], # XXX answer_t
            req => 1,
            pos => 0,
        },
    },
    result_naked => 1,
    result => {
        schema => 'undef',
    },
};
sub ununiquify_answer {
    my %args = @_;

    my $answer = delete $args{answer};
    my $words = ref($answer) eq 'HASH' ? $answer->{words} : $answer;
    die "ununiquify_answer(): Unknown argument(s): ".join(", ", keys %args)
        if keys %args;

    if (@$words == 1) {
        push @$words, "$words->[0] ";
    }
    undef;
}

1;
# ABSTRACT:

=for Pod::Coverage ^(ununiquify_answer)$

=head1 DESCRIPTION


=head1 FAQ

=head2 Why is fuzzy matching slow?

Example:

 use Benchmark qw(timethis);
 use Complete::Util qw(complete_array_elem);

 # turn off the other non-exact matching methods
 $Complete::Common::OPT_CI = 0;
 $Complete::Common::OPT_WORD_MODE = 0;
 $Complete::Common::OPT_CHAR_MODE = 0;

 my @ary = ("aaa".."zzy"); # 17575 elems
 timethis(20, sub { complete_array_elem(array=>\@ary, word=>"zzz") });

results in:

 timethis 20:  7 wallclock secs ( 6.82 usr +  0.00 sys =  6.82 CPU) @  2.93/s (n=20)

Answer: fuzzy matching is slower than exact matching due to having to calculate
Levenshtein distance. But if you find fuzzy matching too slow using the default
pure-perl implementation, you might want to install
L<Text::Levenshtein::Flexible> (an optional prereq) to speed up fuzzy matching.
After Text::Levenshtein::Flexible is installed:

 timethis 20:  1 wallclock secs ( 1.04 usr +  0.00 sys =  1.04 CPU) @ 19.23/s (n=20)


=head1 ENVIRONMENT

=head2 COMPLETE_UTIL_TRACE

Bool. If set to true, will generate more log statements for debugging (at the
trace level).

=head2 COMPLETE_UTIL_LEVENSHTEIN => str ('pp'|'xs'|'flexible')

Can be used to force which Levenshtein distance implementation to use. C<pp>
means the included PP implementation, which is the slowest (1-2 orders of
magnitude slower than XS implementations), C<xs> which means
L<Text::Levenshtein::XS>, or C<flexible> which means
L<Text::Levenshtein::Flexible> (performs best).

If this is not set, the default is to use Text::Levenshtein::Flexible when it's
available, then fallback to the included PP implementation.


=head1 SEE ALSO

L<Complete>

If you want to do bash tab completion with Perl, take a look at
L<Complete::Bash> or L<Getopt::Long::Complete> or L<Perinci::CmdLine>.

Other C<Complete::*> modules.

L<Bencher::Scenarios::CompleteUtil>
