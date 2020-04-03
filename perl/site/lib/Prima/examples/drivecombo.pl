=pod

=head1 NAME

examples/drivecombo.pl - File tree widgets

=head1 FEATURES

Use of standard file-listbox and drive-combo box ( the latter
is idle under *nix )

=cut

use strict;
use warnings;
use Prima::ComboBox;
use Prima::FileDialog;

package UserInit;
$::application = Prima::Application-> create( name => "DriveCombo");

my $w = Prima::MainWindow-> create(
	text   => "Combo box",
	left   => 100,
	bottom => 300,
	width  => 250,
	height => 250,
);

$w-> insert( DriveComboBox =>
	pack => { side => 'bottom', padx => 20, pady => 20, fill => 'x' },
	onChange => sub { $w-> DirectoryListBox1-> path( $_[0]-> text); },
);

$w-> insert( DirectoryListBox =>
	pack => { side => 'bottom', padx => 20, pady => 20, fill => 'both', expand => 1, },
	onChange => sub { print $_[0]-> path."\n"},
);

run Prima;
