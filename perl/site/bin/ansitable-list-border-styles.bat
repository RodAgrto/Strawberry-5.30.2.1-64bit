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

if ($ARGV[0]) {
    $t->border_style($ARGV[0]);
}

my $all_bs = $t->list_border_styles(1);

$t->columns(['Name', 'Summary', 'box_chars?', 'utf8?']);
my $utf8; # we sort by not utf8 and then utf8, just to demonstrate add_row_separator
for my $name (sort {($all_bs->{$a}{utf8} ? 1:0)<=>($all_bs->{$b}{utf8} ? 1:0) || $a cmp $b} keys %$all_bs) {
    my $bs = $all_bs->{$name};
    my $selected = $name eq $t->border_style->{name};
    $t->add_row(
        [$name . ($selected ? " (*)" : ""), $bs->{summary}, $bs->{box_chars} ? 1:0, $bs->{utf8} ? 1:0],
        {fgcolor=>$selected && $t->use_color ? "aaaa00" : undef});

    if (!$utf8 && $bs->{utf8}) {
        $t->add_row_separator;
        $utf8++;
    }
}

say "Tip: you can run me with border style name as argument to try it out.";
print $t->draw;

#use Data::Dump; dd $t->{_row_separators}; dd $t->{_draw}{frow_separators};

# ABSTRACT: List available border styles for Text::ANSITable
# PODNAME: ansitable-list-border-styles

__END__

=pod

=encoding UTF-8

=head1 NAME

ansitable-list-border-styles - List available border styles for Text::ANSITable

=head1 VERSION

This document describes version 0.501 of ansitable-list-border-styles (from Perl distribution Text-ANSITable), released on 2018-12-02.

=head1 SYNOPSIS

 % ansitable-list-border-styles

Sample output:

 Tip: you can run me with border style name as argument to try it out.
 .----------------------------------------------------------------------------------------------------------------------.
 | Name                         Summary                                                              box_chars?   utf8? |
 |                                                                                                                      |
 | Default::none_ascii          No border                                                                N          N   |
 | Default::none_boxchar        No border                                                                Y          N   |
 | Default::single_ascii        Single                                                                   N          N   |
 | Default::single_boxchar      Single                                                                   Y          N   |
 | Default::singleh_ascii       Single, horizontal only                                                  N          N   |
 | Default::singleh_boxchar     Single, horizontal only                                                  Y          N   |
 | Default::singlei_ascii       Single, inner only (like in psql command-line client)                    N          N   |
 | Default::singlei_boxchar     Single, inner only (like in psql command-line client)                    Y          N   |
 | Default::singleo_ascii (*)   Single, outer only                                                       N          N   |
 | Default::singleo_boxchar     Single, outer only                                                       Y          N   |
 | Default::singlev_ascii       Single border, only vertical                                             N          N   |
 | Default::singlev_boxchar     Single, vertical only                                                    Y          N   |
 | Default::space_ascii         Space as border                                                          N          N   |
 | Default::space_boxchar       Space as border                                                          Y          N   |
 | Default::spacei_ascii        Space, inner-only                                                        N          N   |
 | Default::spacei_boxchar      Space, inner-only                                                        Y          N   |
 | Default::bold                Bold                                                                     N          Y   |
 +----------------------------------------------------------------------------------------------------------------------+
 | Default::brick               Single, bold on bottom right to give illusion of depth                   N          Y   |
 | Default::bricko              Single, outer only, bold on bottom right to give illusion of depth       N          Y   |
 | Default::csingle             Curved single                                                            N          Y   |
 | Default::double              Double                                                                   N          Y   |
 | Default::none_utf8           No border                                                                N          Y   |
 | Default::single_utf8         Single                                                                   N          Y   |
 | Default::singleh_utf8        Single, horizontal only                                                  N          Y   |
 | Default::singlei_utf8        Single, inner only (like in psql command-line client)                    N          Y   |
 | Default::singleo_utf8        Single, outer only                                                       N          Y   |
 | Default::singlev_utf8        Single, vertical only                                                    N          Y   |
 | Default::space_utf8          Space as border                                                          N          Y   |
 | Default::spacei_utf8         Space, inner-only                                                        N          Y   |
 `----------------------------------------------------------------------------------------------------------------------'

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
