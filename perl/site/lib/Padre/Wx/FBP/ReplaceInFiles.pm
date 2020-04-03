package Padre::Wx::FBP::ReplaceInFiles;

## no critic

# This module was generated by Padre::Plugin::FormBuilder::Perl.
# To change this module edit the original .fbp file and regenerate.
# DO NOT MODIFY THIS FILE BY HAND!

use 5.008005;
use utf8;
use strict;
use warnings;
use Padre::Wx ();
use Padre::Wx::Role::Main ();
use Padre::Wx::Choice::Files ();
use Padre::Wx::ComboBox::FindTerm ();
use Padre::Wx::ComboBox::History ();

our $VERSION = '1.01';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Dialog
};

sub new {
	my $class  = shift;
	my $parent = shift;

	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::gettext("Replace in Files"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::DEFAULT_DIALOG_STYLE,
	);

	my $m_staticText2 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Search &Term:"),
	);

	$self->{find_term} = Padre::Wx::ComboBox::FindTerm->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[
			"search",
		],
	);

	Wx::Event::EVT_TEXT(
		$self,
		$self->{find_term},
		sub {
			shift->refresh(@_);
		},
	);

	my $m_staticText21 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Replace With:"),
	);

	$self->{replace_term} = Padre::Wx::ComboBox::History->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[
			"replace",
		],
	);

	Wx::Event::EVT_TEXT(
		$self,
		$self->{replace_term},
		sub {
			shift->refresh(@_);
		},
	);

	my $m_staticText3 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Directory:"),
	);

	$self->{find_directory} = Padre::Wx::ComboBox::History->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		[ 250, -1 ],
		[
			"find_directory",
		],
	);

	$self->{directory} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext("&Browse"),
		Wx::DefaultPosition,
		[ 50, -1 ],
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{directory},
		sub {
			shift->directory(@_);
		},
	);

	my $m_staticText4 = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("File Types:"),
	);

	$self->{find_types} = Padre::Wx::Choice::Files->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[],
	);
	$self->{find_types}->SetSelection(0);

	my $m_staticline2 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::LI_HORIZONTAL,
	);

	$self->{find_case} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext("&Case Sensitive"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	$self->{find_regex} = Wx::CheckBox->new(
		$self,
		-1,
		Wx::gettext("&Regular Expression"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	my $m_staticline1 = Wx::StaticLine->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::LI_HORIZONTAL,
	);

	$self->{replace} = Wx::Button->new(
		$self,
		Wx::ID_OK,
		Wx::gettext("&Replace"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);
	$self->{replace}->SetDefault;

	$self->{cancel} = Wx::Button->new(
		$self,
		Wx::ID_CANCEL,
		Wx::gettext("Cancel"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	my $bSizer4 = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$bSizer4->Add( $self->{find_directory}, 1, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL | Wx::EXPAND, 5 );
	$bSizer4->Add( $self->{directory}, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALIGN_RIGHT | Wx::RIGHT, 5 );

	my $fgSizer2 = Wx::FlexGridSizer->new( 2, 2, 0, 0 );
	$fgSizer2->AddGrowableCol(1);
	$fgSizer2->SetFlexibleDirection(Wx::BOTH);
	$fgSizer2->SetNonFlexibleGrowMode(Wx::FLEX_GROWMODE_SPECIFIED);
	$fgSizer2->Add( $m_staticText2, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL, 5 );
	$fgSizer2->Add( $self->{find_term}, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL | Wx::EXPAND, 5 );
	$fgSizer2->Add( $m_staticText21, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL, 5 );
	$fgSizer2->Add( $self->{replace_term}, 0, Wx::ALL | Wx::EXPAND, 5 );
	$fgSizer2->Add( $m_staticText3, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL, 5 );
	$fgSizer2->Add( $bSizer4, 1, Wx::EXPAND, 5 );
	$fgSizer2->Add( $m_staticText4, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL, 5 );
	$fgSizer2->Add( $self->{find_types}, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::ALL | Wx::EXPAND, 5 );

	my $buttons = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$buttons->Add( $self->{replace}, 0, Wx::ALL, 5 );
	$buttons->Add( 20, 0, 1, Wx::EXPAND, 5 );
	$buttons->Add( $self->{cancel}, 0, Wx::ALL, 5 );

	my $vsizer = Wx::BoxSizer->new(Wx::VERTICAL);
	$vsizer->Add( $fgSizer2, 1, Wx::EXPAND, 5 );
	$vsizer->Add( $m_staticline2, 0, Wx::ALL | Wx::EXPAND, 5 );
	$vsizer->Add( $self->{find_regex}, 0, Wx::ALL, 5 );
	$vsizer->Add( $self->{find_case}, 0, Wx::ALL, 5 );
	$vsizer->Add( $m_staticline1, 0, Wx::ALL | Wx::EXPAND, 5 );
	$vsizer->Add( $buttons, 0, Wx::EXPAND, 5 );

	my $hsizer = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$hsizer->Add( $vsizer, 1, Wx::ALL | Wx::EXPAND, 5 );

	$self->SetSizerAndFit($hsizer);
	$self->Layout;

	return $self;
}

sub find_term {
	$_[0]->{find_term};
}

sub replace_term {
	$_[0]->{replace_term};
}

sub find_directory {
	$_[0]->{find_directory};
}

sub find_types {
	$_[0]->{find_types};
}

sub find_case {
	$_[0]->{find_case};
}

sub find_regex {
	$_[0]->{find_regex};
}

sub replace {
	$_[0]->{replace};
}

sub refresh {
	$_[0]->main->error('Handler method refresh for event find_term.OnText not implemented');
}

sub directory {
	$_[0]->main->error('Handler method directory for event directory.OnButtonClick not implemented');
}

1;

# Copyright 2008-2016 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
