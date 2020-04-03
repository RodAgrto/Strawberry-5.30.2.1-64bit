@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
perl -x -S %0 %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!perl
#line 15

our $DATE = '2018-12-02'; # DATE
our $VERSION = '0.501'; # VERSION

use 5.010;
use strict;
use warnings;

use Text::ANSITable;

binmode(STDOUT, ":encoding(utf8)");

my $t = Text::ANSITable->new;

my $all_sets = $t->list_style_sets(1);

$t->columns(['Name', 'Summary', 'Arguments']);
for (sort keys %$all_sets) {
    my $set = $all_sets->{$_};
    $t->add_row([
        $set->{name},
        $set->{summary},
        join(", ", @{ $set->{args} // []}),
    ]);
}

print $t->draw;

# ABSTRACT: List available style sets for Text::ANSITable
# PODNAME: ansitable-list-style-sets

__END__

=pod

=encoding UTF-8

=head1 NAME

ansitable-list-style-sets - List available style sets for Text::ANSITable

=head1 VERSION

This document describes version 0.501 of ansitable-list-style-sets (from Perl distribution Text-ANSITable), released on 2018-12-02.

=head1 SYNOPSIS

 % ansitable-list-style-sets

Sample output:

 .--------------------------------------------------------------------------------------------------.
 | Name                             Summary                          Arguments                      |
 |                                                                                                  |
 | Text::ANSITable::StyleSet::Alt   Set different foreground         even_bgcolor, even_fgcolor,    |
 | Row                              and/or background color for      odd_bgcolor, odd_fgcolor       |
 |                                  odd/even rows                                                   |
 `--------------------------------------------------------------------------------------------------'

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Text-ANSITable>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Text-ANSITable>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Text-ANSITable>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018, 2017, 2016, 2015, 2014, 2013 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__END__
:endofperl
