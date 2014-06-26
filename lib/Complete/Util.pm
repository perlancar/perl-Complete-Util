package Complete::Util;

use 5.010001;
use strict;
use warnings;
use Log::Any '$log';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       complete_array
                       complete_hash_key
                       complete_env
                       complete_file
                       complete_program

                       mimic_shell_dir_completion

                       parse_shell_cmdline
               );

# VERSION
# DATE

our %SPEC;

$SPEC{complete_array} = {
    v => 1.1,
    summary => 'Complete from array',
    args => {
        array => { schema=>['array*'=>{of=>'str*'}], pos=>0, req=>1 },
        word  => { schema=>[str=>{default=>''}], pos=>1 },
        ci    => { schema=>[bool=>{default=>0}] },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_array {
    my %args  = @_;
    my $array = $args{array} or die "Please specify array";
    my $word  = $args{word} // "";
    my $ci    = $args{ci};

    my $wordu = uc($word);
    my @words;
    for (@$array) {
        next unless 0==($ci ? index(uc($_), $wordu) : index($_, $word));
        push @words, $_;
    }
    $ci ? [sort {lc($a) cmp lc($b)} @words] : [sort @words];
}

$SPEC{complete_hash_key} = {
    v => 1.1,
    summary => 'Complete from hash keys',
    args => {
        hash  => { schema=>['hash*'=>{}], pos=>0, req=>1 },
        word  => { schema=>[str=>{default=>''}], pos=>1 },
        ci    => { schema=>[bool=>{default=>0}] },
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
    my $ci    = $args{ci};

    complete_array(word=>$word, array=>[keys %$hash], ci=>$ci);
}

$SPEC{complete_env} = {
    v => 1.1,
    summary => 'Complete from environment variables',
    description => <<'_',

On Windows, environment variable names are all converted to uppercase. You can
use case-insensitive option (`ci`) to match against original casing.

_
    args => {
        word  => { schema=>[str=>{default=>''}], pos=>0 },
        ci    => { schema=>[bool=>{default=>0}] },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_env {
    my %args  = @_;
    my $word  = $args{word} // "";
    my $ci    = $args{ci};
    if ($word =~ /^\$/) {
        complete_array(word=>$word, array=>[map {"\$$_"} keys %ENV], ci=>$ci);
    } else {
        complete_array(word=>$word, array=>[keys %ENV], ci=>$ci);
    }
}

$SPEC{complete_program} = {
    v => 1.1,
    summary => 'Complete program name found in PATH',
    description => <<'_',

Windows is supported, on Windows PATH will be split using /;/ instead of /:/.

_
    args => {
        word  => { schema=>[str=>{default=>''}], pos=>0 },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_program {
    require List::MoreUtils;

    my %args  = @_;
    my $word  = $args{word} // "";

    my @words;
    my @dir;
    my $word_has_path;
    $word =~ m!(.*)/(.*)! and do { @dir = ($1); $word_has_path++; $word = $2 };
    @dir = split /:/, $ENV{PATH} unless @dir;
    unshift @dir, ".";
    for my $dir (@dir) {
        $dir =~ s!/+$!!; #TEST
        opendir my($dh), $dir or next;
        for (readdir($dh)) {
            next if $word !~ /^\.\.?$/ && ($_ eq '.' || $_ eq '..');
            next unless index($_, $word) == 0;
            next unless (-x "$dir/$_") && (-f _) ||
                ($dir eq '.' || $word_has_path) && (-d _);
            push @words, (-d _) ? "$_/" : $_;
        };
    }

    complete_array(array=>[List::MoreUtils::uniq(@words)]);
}

$SPEC{complete_file} = {
    v => 1.1,
    args => {
        word => { schema=>[str=>{default=>''}], pos=>0 },
        f    => { summary => 'Whether to include file',
                  schema=>[bool=>{default=>1}] },
        d    => { summary => 'Whether to include directory',
                  schema=>[bool=>{default=>1}] },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub complete_file {
    my %args  = @_;
    my $word  = $args{word} // "";
    my $f     = $args{f} // 1;
    my $d     = $args{d} // 1;

    my @all;
    if ($word =~ m!(\A|/)\z!) {
        my $dir = length($word) ? $word : ".";
        opendir my($dh), $dir or return [];
        @all = map { ($dir eq '.' ? '' : $dir) . $_ }
            grep { $_ ne '.' && $_ ne '..' } readdir($dh);
        closedir $dh;
    } else {
        # must add wildcard char, glob() is convoluted. also {a,b} is
        # interpreted by glob() (not so by bash file completion). also
        # whitespace is interpreted by glob :(. later should replace with a
        # saner one, like wildcard2re.
        @all = glob("$word*");
    }

    my @words;
    for (@all) {
        next if (-f $_) && !$f;
        next if (-d _ ) && !$d;
        $_ = "$_/" if (-d _) && !m!/\z!;
        #s!.+/(.+)!$1!;
        push @words, $_;
    }

    my $w = complete_array(array=>\@words);

    mimic_shell_dir_completion(completion=>$w);
}

$SPEC{mimic_shell_dir_completion} = {
    v => 1.1,
    summary => 'Make completion of paths behave more like shell',
    description => <<'_',

This function employs a trick to make directory/path completion work more like
shell's own. In shell, when completing directory, the sole completion for `foo/`
is `foo/`, the cursor doesn't automatically add a space (like the way it does
when there is only a single completion possible). Instead it stays right after
the `/` to allow user to continue completing further deeper in the tree
(`foo/bar` and so on).

To make programmable completion work like shell's builtin dir completion, the
trick is to add another completion alternative `foo/ ` (with an added space) so
shell won't automatically add a space because there are now more than one
completion possible (`foo/` and `foo/ `).

_
    args => {
        completion => { schema=>'str*', req=>1, pos=>0 },
    },
    result_naked => 1,
    result => {
        schema => 'array',
    },
};
sub mimic_shell_dir_completion {
    my %args  = @_;
    my $c  = $args{completion};
    return $c unless @$c == 1 && $c->[0] =~ m!/\z!;
    [$c->[0], "$c->[0] "];
}

# current problems: Can't parse unclosed quotes (e.g. spanel get-plan "BISNIS
# A<tab>) and probably other problems, since we don't have access to COMP_WORDS
# like in shell functions.
sub _line_to_argv {
    require IPC::Open2;

    my $line = pop;
    my $cmd = q{_pbc() { for a in "$@"; do echo "$a"; done }; _pbc } . $line;
    my ($reader, $writer);
    my $pid = IPC::Open2::open2($reader,$writer,'bash 2>/dev/null');
    print $writer $cmd;
    close $writer;
    my @array = map {chomp;$_} <$reader>;

    # We don't want to expand ~ for user experience and to be consistent with
    # Bash's behavior for tab completion (as opposed to expansion of ARGV).
    my $home_dir = (getpwuid($<))[7];
    @array = map { s!\A\Q$home_dir\E(/|\z)!\~$1!; $_ } @array;

    \@array;
}

# simplistic parsing, doesn't consider shell syntax at all. doesn't work the
# minute we use funny characters.
#sub _line_to_argv_BC {
#    [split(/\h+/, $_[0])];
#}

$SPEC{parse_shell_cmdline} = {
    v => 1.1,
    summary => 'Parse shell command-line for processing by completion routines',
    description => <<'_',

Currently only supports bash.

Returns hash with the following keys: `words` (array of str, equivalent to
`COMP_WORDS` provided by shell to completion routine), `cword` (int, equivalent
to shell-provided `COMP_CWORD`).

_
    args_as => 'array',
    args => {
        cmdline => {
            summary => 'Command-line, defaults to COMP_LINE environment',
            schema => 'str*',
            pos => 0,
        },
        point => {
            summary => 'Point/position to complete in command-line, '.
                'defaults to COMP_POINT',
            schema => 'int*',
            pos => 1,
        },
        opts => {
            schema => 'hash*',
            description => <<'_',

Currently known options: parse_line_sub (code).

_
            pos => 2,
        },
    },
    result_naked => 1,
    result => {
        schema => [hash => {keys => {
            words=>['array*' => of => 'str*'],
            cword=>'int*',
        }}],
    },
};
sub parse_shell_cmdline {
    my ($line, $point, $opts) = @_;
    $opts //= {};
    $opts->{parse_line_sub} //= \&_line_to_argv;

    $line  //= $ENV{COMP_LINE};
    $point //= $ENV{COMP_POINT};

    my $left  = substr($line, 0, $point);
    my $right = substr($line, $point);
    $log->tracef("line=<%s>, point=%s, left=<%s>, right=<%s>",
                 $line, $point, $left, $right);

    my @left;
    if (length($left)) {
        @left = @{ $opts->{parse_line_sub}->($left) };
        # shave off $0
        substr($left, 0, length($left[0])) = "";
        $left =~ s/^\s+//;
        shift @left;
    }

    my @right;
    if (length($right)) {
        # shave off the rest of the word at "cursor"
        $right =~ s/^\S+//;
        @right = @{ $opts->{parse_line_sub}->($right) } if length($right);
    }
    $log->tracef("\@left=%s, \@right=%s", \@left, \@right);

    my $words = [@left, @right],
    my $cword = @left ? scalar(@left)-1 : 0;

    # is there a space after the final word (e.g. "foo bar ^" instead of "foo
    # bar^" or "foo bar\ ^")? if yes then cword is on the next word.
    my $tmp = $left;
    my $nspc_left = 0; $nspc_left++ while $tmp =~ s/\s$//;
    $tmp = $left[-1];
    my $nspc_lastw = 0;
    if (defined($tmp)) { $nspc_lastw++ while $tmp =~ s/\s$// }
    $cword++ if $nspc_lastw < $nspc_left;

    my $res = {words => $words, cword => $cword};
    $res;
}

1;
# ABSTRACT: Shell tab completion routines
