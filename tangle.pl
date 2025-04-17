#!/usr/bin/perl -w
use strict;

my $inp = *STDIN;
if ($ARGV[0]) {
    open $inp, "<", $ARGV[0] or die "$!";
}
my $out = *STDOUT;
if ($ARGV[1]) {
    open $out, ">", $ARGV[1] or die "$!";
}

my $root = undef;
my %blocks;

sub get_label_from_short_form {
    my $label = shift;
    my @matches = grep { index($_, $label) == 0 } keys %blocks;
    return scalar @matches == 1 ? $matches[0] : "";
}

# slurp
$/ = undef;
my $data = <$inp>;

my $pat = qr/^```(\N*)\n«(\N+?)»(\+?=)?\n(.*?)^```\n/ms;
while ($data =~ m/$pat/g) {
    my (undef, $label, $op, $code) = ($1, $2, $3, $4);
    # printf "%s\n====\n%s----\n", $label, $code;
    $label =~ s/^\s*//;
    $label =~ s/\s*$//;

    if (not defined $op) {
        die "saw multiple root labels (first was $root)" if defined $root;
        $root = $label;
        $blocks{$root} = "";
    } elsif ($op eq "=") {
        my $exists = get_label_from_short_form($label);
        if ($exists) {
            die "tried to initialize $exists twice" if $blocks{$exists};
            $blocks{$exists} = $code;
        } else {
            $blocks{$label} = $code;
        }
    } elsif ($op eq "+=") {
        my $exists = get_label_from_short_form($label);
        if ($exists) {
            $blocks{$exists} .= $code;
        } else {
            die "tried to append to $label before initialization";
        }
    }
}

# assemble
my $prog = $blocks{$root};
while ($prog =~ /«(.*?)»/) {
    # printf ">>>\n%s\n<<<\n", $prog;
    my $label = $1;
    $label =~ s/^\s*//;
    $label =~ s/\s*$//;

    my $exists = get_label_from_short_form($label);
    die "unknown block $label" unless ($exists);
    $prog =~ s/«.*?»/$blocks{$exists}/;
}
print $out $prog;
