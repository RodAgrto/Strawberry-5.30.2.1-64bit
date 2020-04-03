package Sort::Sub::asciibetically;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2020-02-28'; # DATE
our $DIST = 'Sort-Sub'; # DIST
our $VERSION = '0.118'; # VERSION

use 5.010;
use strict;
use warnings;

sub meta {
    return {
        v => 1,
        summary => 'Sort ascibetically (string-wise)',
    };
}

sub gen_sorter {
    my ($is_reverse, $is_ci) = @_;

    sub {
        no strict 'refs';

        my $caller = caller();
        my $a = @_ ? $_[0] : ${"$caller\::a"};
        my $b = @_ ? $_[1] : ${"$caller\::b"};

        my $cmp = $is_ci ? lc($a) cmp lc($b) : $a cmp $b;
        $is_reverse ? -1*$cmp : $cmp;
    };
}

1;
# ABSTRACT: Sort ascibetically (string-wise)

__END__

=pod

=encoding UTF-8

=head1 NAME

Sort::Sub::asciibetically - Sort ascibetically (string-wise)

=head1 VERSION

This document describes version 0.118 of Sort::Sub::asciibetically (from Perl distribution Sort-Sub), released on 2020-02-28.

=head1 SYNOPSIS

Generate sorter (accessed as variable) via L<Sort::Sub> import:

 use Sort::Sub '$asciibetically'; # use '$asciibetically<i>' for case-insensitive sorting, '$asciibetically<r>' for reverse sorting
 my @sorted = sort $asciibetically ('item', ...);

Generate sorter (accessed as subroutine):

 use Sort::Sub 'asciibetically<ir>';
 my @sorted = sort {asciibetically} ('item', ...);

Generate directly without Sort::Sub:

 use Sort::Sub::asciibetically;
 my $sorter = Sort::Sub::asciibetically::gen_sorter(
     ci => 1,      # default 0, set 1 to sort case-insensitively
     reverse => 1, # default 0, set 1 to sort in reverse order
 );
 my @sorted = sort $sorter ('item', ...);

Use in shell/CLI with L<sortsub> (from L<App::sortsub>):

 % some-cmd | sortsub asciibetically
 % some-cmd | sortsub asciibetically --ignore-case -r

=head1 DESCRIPTION

This is equivalent to Perl's:

 sub { $a cmp $b }

=for Pod::Coverage ^(gen_sorter|meta)$

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Sort-Sub>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Sort-Sub>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Sort-Sub>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 SEE ALSO

L<Sort::Sub>

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020, 2019, 2018, 2016, 2015 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
