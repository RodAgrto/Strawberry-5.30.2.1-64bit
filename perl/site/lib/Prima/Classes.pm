
#  Created by:
#     Anton Berezin  <tobez@tobez.org>
#     Dmitry Karasik <dmitry@karasik.eu.org>
#
package Prima::Classes;
use strict;
use warnings;
use Prima;
use Prima::Const;

package Prima::array;
use base 'Tie::Array';

sub new
{
	my ($class, $letter) = @_;
	die "bad array type" if $letter !~ /^[id]$/;
	my @tie;
	my $size = length pack $letter, 0;
	my $buf = '';
	tie @tie, $class, $buf, $size, $letter;
	return \@tie;
}

sub new_int    { shift->new('i') }
sub new_double { shift->new('d') }

use constant REF  => 0;
use constant SIZE => 1;
use constant PACK => 2;

sub is_array { ((ref tied @{$_[0]}) // '') eq 'Prima::array' }

sub append
{
	die "bad array" if grep { !is_array($_) } @_;
	my ( $a1, $a2 ) = map { tied @$_ } @_;
	die "bad array" if $a1->[PACK] ne $a2->[PACK];
	$a1->[REF] .= $a2->[REF];
}

sub TIEARRAY  { bless \@_, shift }
sub FETCH     { unpack( $_[0]->[PACK], substr( $_[0]->[REF], $_[1] * $_[0]->[SIZE], $_[0]->[SIZE] )) }
sub STORE     { substr( $_[0]->[REF], $_[1] * $_[0]->[SIZE], $_[0]->[SIZE], pack( $_[0]->[PACK], $_[2] )) }
sub FETCHSIZE { length( $_[0]->[REF] ) / $_[0]->[SIZE] }
sub EXISTS    { $_[1] < FETCHSIZE($_[0]) }
sub STORESIZE {
	( $_[1] > FETCHSIZE($_[0]) ) ?
		(STORE($_[0], $_[1] - 1, 0)) :
		(substr( $_[0]->[REF], $_[1] * $_[0]->[SIZE] ) = '' )
}
sub DELETE    { warn "This array does not implement delete functionality" }

# class Object; base class of all Prima classes
package Prima::Object;
use vars qw(@hooks);
use Carp;

sub CLONE_SKIP { 1 }

sub new { shift-> create(@_) }

sub CREATE
{
	my $class = shift;
	my $self = {};
	bless( $self, $class);
	return $self;
}

sub DESTROY
{
	my $self = shift;
	my $class = ref( $self);
	::destroy_mate( $self);
}

sub profile_add
{
	my ($self,$profile) = @_;
	my $default  = $_[0]-> profile_default;
	$_-> ( $self, $profile, $default) for @hooks;
	$self-> profile_check_in( $profile, $default);
	delete @$default{keys %$profile};
	@$profile{keys %$default}=values %$default;
	delete $profile-> {__ORDER__};
	$profile-> {__ORDER__} = [keys %$profile];
#	%$profile = (%$default, %$profile);
}

sub profile_default
{
	return {};
}

sub profile_check_in {};

sub raise_ro { croak "Attempt to write read-only property \"$_[1]\""; }
sub raise_wo { croak "Attempt to read write-only property \"$_[1]\""; }

sub set {
	for ( my $i = 1; $i < @_; $i += 2) {
		my $sub_set = $_[$i];
		$_[0]-> $sub_set( $_[$i+1]);
	}
	return;
}

sub get
{
	my $self = shift;
	map {
		my @val = $self-> $_();
		$_ => ((1 == @val) ? $val[0] : \@val)
	} @_;
}

package Prima::Font;

sub new
{
	my $class = shift;
	my $self = { OWNER=>shift, READ=>shift, WRITE=>shift};
	bless( $self, $class);
	my ($o,$r,$w) = @{$self}{"OWNER","READ","WRITE"};
	my $f = $o-> $r();
	$self-> update($f);
	return $self;
}

sub update
{
	my ( $self, $f) = @_;
	for ( keys %{$f}) { $self-> {$_} = $f-> {$_}; }
}

sub set
{
	my ($o,$r,$w) = @{$_[0]}{"OWNER","READ","WRITE"};
	my ($self, %pr) = @_;
	$self-> update( \%pr);
	$o-> $w( \%pr);
}

for ( qw( size name width height direction style pitch encoding vector)) {
	eval <<GENPROC;
   sub $_
   {
      my (\$o,\$r,\$w) = \@{\$_[0]}{"OWNER","READ","WRITE"};
      my \$font = \$#_ ? {$_ => \$_[1]} : \$o->\$r();
      return \$#_ ? (\$_[0]->update(\$font), \$o->\$w(\$font)) : \$font->{$_};
   }
GENPROC
}

for ( qw( ascent descent family weight maximalWidth internalLeading externalLeading
	xDeviceRes yDeviceRes firstChar lastChar breakChar defaultChar 
)) {
	eval <<GENPROC;
   sub $_
   {
      my (\$o,\$r) = \@{\$_[0]}{"OWNER","READ"};
      my \$font = \$o->\$r();
      return \$#_ ? Prima::Object-> raise_ro("Font::$_") : \$font->{$_};
   }
GENPROC
}


sub DESTROY {}

package Prima::Component;
use vars qw(@ISA);
@ISA = qw(Prima::Object);

{
my %RNT = (
	ChangeOwner => nt::Default,
	ChildEnter  => nt::Default,
	ChildLeave  => nt::Default,
	Create      => nt::Default,
	Destroy     => nt::Default,
	PostMessage => nt::Default,
);

sub notification_types { return \%RNT; }
}

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		name        => ref $_[ 0],
		owner       => $::application,
		delegations => undef,
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub profile_check_in
{
	my ( $self, $p, $default) = @_;
	my $owner = $p-> {owner} ? $p-> {owner} : $default-> {owner};
	$self-> SUPER::profile_check_in( $p, $default);
	if (
		defined $owner
		and !exists( $p-> {name})
		and $default-> {name} eq ref $self
	) {
		$p-> {name} = ( ref $self) .  (
			1 + map {
				(ref $self) eq (ref $_) ? 1 : ()
			} $owner-> get_components
		);
		$p-> { name} =~ s/(.*):([^:]+)$/$2/;
	}
}

sub get_notify_sub
{
	my ($self, $note) = @_;
	my $rnt = $self-> notification_types-> {$note};
	$rnt = nt::Default unless defined $rnt;
	if ( $rnt & nt::CustomFirst) {
		my ( $referer, $sub, $id) = $self-> get_notification(
			$note,
			($rnt & nt::FluxReverse) ? -1 : 0
		);
		if ( defined $referer) {
			return $sub, $referer, $self if $referer != $self;
			return $sub, $self;
		}
		my $method = "on_" . lc $note;
		return ( $sub, $self) if $sub = $self-> can( $method);
	} else {
		my ( $sub, $method) = ( undef, "on_" . lc $note);
		return ( $sub, $self) if $sub = $self-> can( $method);
		my ( $referer, $sub2, $id) = $self-> get_notification( $note, ($rnt & nt::FluxReverse) ? -1 : 0);
		if ( defined $referer) {
			return ( $sub, $referer, $self) if $referer != $self;
			return ( $sub, $self);
		}
	}
	return undef;
}

sub AUTOLOAD
{
	no strict;
	my $self = shift;
	my $expectedMethod = $AUTOLOAD;
	Carp::confess "There is no such thing as \"$expectedMethod\"\n"
		if scalar(@_) or not ref $self;
	my ($componentName) = $expectedMethod =~ /::([^:]+)$/;
	my $component = $self-> bring( $componentName);
	Carp::croak("Unknown widget or method \"$expectedMethod\"")
		unless $component && ref($component);
	return $component;
}

sub find_component
{
	my ( $self, $name ) = @_;
	my @q = $self-> get_components;
	while ( my $x = shift @q ) {
		return $x if $x-> name eq $name;
		push @q, $x-> get_components;
	}
	return undef;
}

package Prima::File;
use vars qw(@ISA);
@ISA = qw(Prima::Component);

{
my %RNT = (
	%{Prima::Component-> notification_types()},
	Read        => nt::Default,
	Write       => nt::Default,
	Exception   => nt::Default,
);

sub notification_types { return \%RNT; }
}


sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		file  => undef,
		fd    => -1,
		mask  => fe::Read | fe::Write | fe::Exception,
		owner => undef,
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

package Prima::Clipboard;
use vars qw(@ISA);
@ISA = qw(Prima::Component);

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	$def-> {name} = 'Clipboard';
	return $def;
}

sub has_format
{
	my ( $self, $format ) = @_;
	$self-> open;
	my $exists = 0;
	$::application-> notify( 'FormatExists', $format, $self, \$exists );
	$self-> close;
	return $exists ? 1 : 0;
}

sub copy
{
	my ( $self, $format, $data ) = @_;
	$self-> open;
	$self-> clear;
	$::application-> notify( 'Copy', $format, $self, $data );
	$self-> close;
}

sub paste
{
	my ( $self, $format ) = @_;
	my $data;
	$::application-> notify( 'Paste', $format, $_[0], \$data);
	return $data;
}

sub text  { $#_ ? $_[0]->copy('Text',  $_[1]) : $_[0]->paste('Text') }
sub image { $#_ ? $_[0]->copy('Image', $_[1]) : $_[0]->paste('Image') }

package Prima::Region;
use vars qw(@ISA);
@ISA = qw(Prima::Component);

sub origin { (shift->box)[0,1] }
sub size   { (shift->box)[2,3] }
sub rect
{
	my @box = shift->box;
	return @box[0,1], $box[0] + $box[2], $box[1] + $box[3];
}

sub dup
{
	my $r = ref($_[0])->new;
	$r->combine($_[0], rgnop::Copy);
	return $r;
}

sub bitmap_or_image
{
	my ($self, $class, %param) = @_;
	return undef if $self-> is_empty;
	my @box = $self->box;
	my @size = @box[2,3];

	my $with_offset = delete $param{with_offset};
	if ( $with_offset ) {
		$size[0] += $box[0];
		$size[1] += $box[1];
	}
	my $dbm = $class->new( size => \@size, %param);
	$dbm-> clear;
	$self-> offset( -$box[0], -$box[1]) unless $with_offset;
	$dbm-> region($self);
	$self-> offset( $box[0], $box[1]) unless $with_offset;
	$dbm-> bar(0,0,@size);
	return $dbm;
}

sub bitmap { shift->bitmap_or_image( 'Prima::DeviceBitmap', type => dbt::Bitmap, @_ ) }
sub image  { shift->bitmap_or_image( 'Prima::Image',        type => im::BW,      @_ ) }

package Prima::Drawable;
use vars qw(@ISA);
@ISA = qw(Prima::Component);
use Prima::Bidi qw(is_bidi);
use Prima::Drawable::Basic;

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		color           => cl::Black,
		backColor       => cl::White,
		fillMode        => fm::Overlay|fm::Alternate,
		fillPattern     => fp::Solid,
		fillPatternOffset => [0,0],
		font            => {
			height      => 16,
			width       => 0,
			pitch       => fp::Default,
			style       => fs::Normal,
			direction   => 0,
			vector      => fv::Default,
			name        => "Default",
			encoding    => "",
		},
		lineEnd         => le::Round,
		lineJoin        => lj::Round,
		linePattern     => lp::Solid,
		lineWidth       => 0,
		miterLimit      => 10.0,
		owner           => undef,
		palette         => [],
		region          => undef,
		rop             => rop::CopyPut,
		rop2            => rop::NoOper,
		textOutBaseline => 0,
		textOpaque      => 0,
		translate       => [ 0, 0],
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub profile_check_in
{
	my ( $self, $p, $default) = @_;
	$self-> SUPER::profile_check_in( $p, $default);
	$p-> { font} = {} unless exists $p-> { font};
	$p-> { font} = Prima::Drawable-> font_match( $p-> { font}, $default-> { font});
	$p->{fillMode} = ( delete($p->{fillWinding}) ? fm::Winding : fm::Alternate) | fm::Overlay
		if exists $p->{fillWinding} && ! exists $p->{fillMode}; # compatibility
}

sub font
{
	($#_) ?
		$_[0]-> set_font( $#_ > 1 ?
			{@_[1 .. $#_]} :
			$_[1]
		) :
		return Prima::Font-> new(
			$_[0], "get_font", "set_font"
		)
}

sub put_image
{
	$_[0]-> put_image_indirect(
		@_[3,1,2], 0, 0,
		($_[3]-> size) x 2,
		defined ($_[4]) ? $_[4] : $_[0]-> rop
	) if $_[3]
}

sub stretch_image {
	$_[0]-> put_image_indirect(
		@_[5,1,2], 0, 0,
		@_[3,4], $_[5]-> size,
		defined ($_[6]) ? $_[6] : $_[0]-> rop
	) if $_[5]
}

sub text_out_bidi
{
	if ( $Prima::Bidi::enabled && is_bidi $_[1] ) {
		return shift->text_out( Prima::Bidi::visual(shift), @_);
	} else {
		return shift->text_out(@_);
	}
}

sub has_alpha_layer { 0 }

sub spline
{
	my $self = shift;
	$self->polyline( $self->render_spline(@_) );
}

sub fill_spline
{
	my $self = shift;
	$self->fillpoly( $self->render_spline(@_) );
}

sub fillWinding # compatibility
{
	return $_[0]->fillMode & fm::Winding unless $#_;
	$_[0]->fillMode(($_[1] ? fm::Winding : fm::Alternate) | fm::Overlay);
}

package Prima::Image;
use vars qw( @ISA);
@ISA = qw(Prima::Drawable);

{
my %RNT = (
	%{Prima::Drawable-> notification_types()},
	HeaderReady => nt::Default,
	DataReady   => nt::Default,
);

sub notification_types { return \%RNT; }
}

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		conversion    => ict::Optimized,
		data          => '',
		height        => 0,
		scaling       => ist::Box,
		palette       => [0, 0, 0, 0xFF, 0xFF, 0xFF],
		colormap      => undef,
		preserveType  => 0,
		rangeLo       => 0,
		rangeHi       => 1,
		resolution    => [0, 0],
		type          => im::Mono,
		width         => 0,
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub profile_check_in
{
	my ( $self, $p, $default) = @_;

	if ( exists $p-> {colormap} and not exists $p-> {palette}) {
		$p-> {palette} = [ map {
			( $_        & 0xFF),
			(($_ >> 8)  & 0xFF),
			(($_ >> 16) & 0xFF),
		} @{$p-> {colormap}} ];
		delete $p-> {colormap};
	}

	if ( exists $p->{size} ) {
		$p->{width}  //= $p->{size}->[0];
		$p->{height} //= $p->{size}->[1];
	}

	$self-> SUPER::profile_check_in( $p, $default);
}

sub rangeLo      { return shift-> stats( is::RangeLo , @_); }
sub rangeHi      { return shift-> stats( is::RangeHi , @_); }
sub sum          { return shift-> stats( is::Sum     , @_); }
sub sum2         { return shift-> stats( is::Sum2    , @_); }
sub mean         { return shift-> stats( is::Mean    , @_); }
sub variance     { return shift-> stats( is::Variance, @_); }
sub stdDev       { return shift-> stats( is::StdDev  , @_); }

sub colormap
{
	if ( $#_) {
		shift-> palette([ map {
			( $_        & 0xFF),
			(($_ >> 8)  & 0xFF),
			(($_ >> 16) & 0xFF),
		} @_ ]);
	} else {
		my $p = $_[0]-> palette;
		my ($i,@r);
		for ($i = 0; $i < @$p; $i += 3) {
			push @r, $$p[$i] + ($$p[$i+1] << 8) + ($$p[$i+2] << 16);
		}
		return @r;
	}
}

sub clone
{
	my $i = shift->dup;
	$i->set(@_);
	return $i;
}

sub ui_scale
{
	my ($self, %opt) = @_;

	my $zoom = delete($opt{zoom}) // ( $::application ? $::application->uiScaling : 1 );
	return $self if $zoom == 1.0;

	my $scaling = delete($opt{scaling}) // ist::Quadratic;
	$self->set(
		%opt,
		scaling => $scaling,
		size => [ map { $_ * $zoom } $self->size ],
	);
	return $self;
}

sub to_region { Prima::Region->new( image => shift ) }

sub shear { $_[0]->transform(1,@_[2,1],1) }

package Prima::Icon;
use vars qw( @ISA);
@ISA = qw(Prima::Image);

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		autoMasking => am::Auto,
		mask        => '',
		maskType    => im::bpp1,
		maskColor   => 0,
		maskIndex   => 0,
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub profile_check_in
{
	my ( $self, $p, $default) = @_;

	if ( exists $p-> {mask} and not exists $p-> {autoMasking}) {
		$p-> {autoMasking} = am::None;
	}
	$self-> SUPER::profile_check_in( $p, $default);
}

sub mirror
{
        my ($self, $vertically) = @_;
        my ($xor, $and) = $self->split;
        $and->preserveType(1);
        $_->mirror($vertically) for $xor, $and;
        $self->combine($xor, $and);
}

sub create_combined
{
	my $self = shift->new( autoMasking => am::None );
	$self->combine(@_);
	return $self;
}

sub has_alpha_layer { shift->maskType == im::bpp8 }

sub ui_scale
{
	my ($self, %opt) = @_;

	my $zoom = delete($opt{zoom}) // ( $::application ? $::application->uiScaling : 1 );
	return $self if $zoom == 1.0;

	my $argb    = delete($opt{argb})    // ($::application ? $::application-> get_system_value( sv::LayeredWidgets ) : 0);
	my $scaling = delete($opt{scaling}) // ($argb ? ist::Quadratic : ist::Box );

	if ( $scaling <= ist::Box ) {
		# don't uglify bitmaps with box scaling where zoom is 1.25 or 2.75
		$zoom = int($zoom + .5);
		return $self if $zoom <= 1.0;
	}

	$self->set(
		%opt,
		scaling => $scaling,
		size => [ map { $_ * $zoom } $self->size ],
	);

	return $self;
}

sub image
{
	my ($self,%opt) = @_;
	my ($image, undef) = $self-> split;
	$image->backColor($opt{background} // 0);
	$image->clear;
	$image->put_image(0,0,$self,rop::CopyPut);
	return $image;
}

package Prima::DeviceBitmap;
use vars qw( @ISA);
@ISA = qw(Prima::Drawable);

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		height       => 0,
		width        => 0,
		type         => dbt::Pixmap,
		monochrome   => undef, # back-compat
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub profile_check_in
{
	my ( $self, $p, $default) = @_;

	if ( exists $p-> {monochrome} and not exists $p-> {type}) {
		$p-> {type} = $p->{monochrome} ? dbt::Bitmap : dbt::Pixmap;
	}
	if ( exists $p->{size} ) {
		$p->{width}  //= $p->{size}->[0];
		$p->{height} //= $p->{size}->[1];
	}
	$self-> SUPER::profile_check_in( $p, $default);
}

sub has_alpha_layer { shift->type == dbt::Layered }

sub dup 
{
	my $self = shift;
	my $dup = ref($self)->new(
		size => [ $self->size ],
		type => $self->type
	);
	$dup->backColor(0);
	$dup->clear;
	$dup->put_image(0,0,$self,rop::SrcOver);
	return $dup;
}

package Prima::Timer;
use vars qw(@ISA);
@ISA = qw(Prima::Component);

{
my %RNT = (
	%{Prima::Component-> notification_types()},
	Tick => nt::Default,
);

sub notification_types { return \%RNT; }
}

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		timeout => 1000,
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub toggle { $_[0]->get_active ? $_[0]->stop : $_[0]->start }

package Prima::Printer;
use vars qw(@ISA);
@ISA = qw(Prima::Drawable);

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		printer => '',
		owner   => $::application,
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

package Prima::Widget;
use vars qw(@ISA %WidgetProfile @default_font_box);
@ISA = qw(Prima::Drawable);

{
my %RNT = (
	%{Prima::Drawable-> notification_types()},
	Change         => nt::Default,
	Click          => nt::Default,
	Close          => nt::Command,
	ColorChanged   => nt::Default,
	Disable        => nt::Default,
	DragBegin      => nt::Command,
	DragOver       => nt::Command,
	DragEnd        => nt::Command,
	DragQuery      => nt::Command,
	DragResponse   => nt::Command,
	Enable         => nt::Default,
	Enter          => nt::Default,
	FontChanged    => nt::Default,
	Hide           => nt::Default,
	Hint           => nt::Default,
	KeyDown        => nt::Command,
	KeyUp          => nt::Command,
	Leave          => nt::Default,
	Menu           => nt::Default,
	MouseClick     => nt::Command,
	MouseDown      => nt::Command,
	MouseUp        => nt::Command,
	MouseMove      => nt::Command,
	MouseWheel     => nt::Command,
	MouseEnter     => nt::Command,
	MouseLeave     => nt::Command,
	Move           => nt::Default,
	Paint          => nt::Action,
	Popup          => nt::Command,
	Setup          => nt::Default,
	Show           => nt::Default,
	Size           => nt::Default,
	TranslateAccel => nt::Default,
	SysHandle      => nt::Default,
	ZOrderChanged  => nt::Default,
);

sub notification_types { return \%RNT; }
}

%WidgetProfile = (
	accelTable        => undef,
	accelItems        => undef,
	autoEnableChildren=> 0,
	backColor         => cl::Normal,
	briefKeys         => 1,
	buffered          => 0,
	clipChildren      => 1,
	capture           => 0,
	clipOwner         => 1,
	color             => cl::NormalText,
	bottom            => 100,
	centered          => 0,
	current           => 0,
	currentWidget     => undef,
	cursorVisible     => 0,
	dark3DColor       => cl::Dark3DColor,
	disabledBackColor => cl::Disabled,
	disabledColor     => cl::DisabledText,
	dndAware          => 0,
	enabled           => 1,
	firstClick        => 1,
	focused           => 0,
	geometry          => gt::GrowMode,
	growMode          => 0,
	height            => 100,
	helpContext       => '',
	hiliteBackColor   => cl::Hilite,
	hiliteColor       => cl::HiliteText,
	hint              => '',
	hintVisible       => 0,
	layered           => 0,
	light3DColor      => cl::Light3DColor,
	left              => 100,
	ownerColor        => 0,
	ownerBackColor    => 0,
	ownerFont         => 1,
	ownerHint         => 1,
	ownerShowHint     => 1,
	ownerPalette      => 1,
	packInfo          => undef,
	packPropagate     => 1,
	placeInfo         => undef,
	pointerIcon       => undef,
	pointer           => cr::Default,
	pointerType       => cr::Default,
	popup             => undef,
	popupColor             => cl::NormalText,
	popupBackColor         => cl::Normal,
	popupHiliteColor       => cl::HiliteText,
	popupHiliteBackColor   => cl::Hilite,
	popupDisabledColor     => cl::DisabledText,
	popupDisabledBackColor => cl::Disabled,
	popupLight3DColor      => cl::Light3DColor,
	popupDark3DColor       => cl::Dark3DColor,
	popupItems        => undef,
	right             => 200,
	scaleChildren     => 1,
	selectable        => 0,
	selected          => 0,
	selectedWidget    => undef,
	selectingButtons  => mb::Left,
	shape             => undef,
	showHint          => 1,
	syncPaint         => 0,
	tabOrder          => -1,
	tabStop           => 1,
	text              => undef,
	textOutBaseline   => 0,
	top               => 200,
	transparent       => 0,
	visible           => 1,
	widgetClass       => wc::Custom,
	widgets           => undef,
	width             => 100,
	x_centered        => 0,
	y_centered        => 0,
);

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;

	@$def{keys %WidgetProfile} = values %WidgetProfile;

	my %WidgetProfile = (
		# secondary; contains anonymous arrays that must be generated at every invocation
		cursorPos         => [ 0, 0],
		cursorSize        => [ 12, 3],
		designScale       => [ 0, 0],
		origin            => [ 0, 0],
		owner             => $::application,
		pointerHotSpot    => [ 0, 0],
		rect              => [ 0, 0, 100, 100],
		size              => [ 100, 100],
		sizeMin           => [ 0, 0],
		sizeMax           => [ 16384, 16384],
	);
	@$def{keys %WidgetProfile} = values %WidgetProfile;
	@$def{qw( font popupFont)} = ( $_[ 0]-> get_default_font, $_[ 0]-> get_default_popup_font);
	return $def;
}

sub profile_check_in
{
	my ( $self, $p, $default) = @_;
	my $orgFont = exists $p-> { font} ? $p-> { font} : undef;
	my $owner = exists $p-> { owner} ? $p-> { owner} : $default-> { owner};
	$self-> SUPER::profile_check_in( $p, $default);
	delete $p-> { font} unless defined $orgFont;

	my $name = defined $p-> {name} ? $p-> {name} : $default-> {name};
	$p-> {text} = $name
		if !defined $p-> { text} and !defined $default-> {text};

	$p-> {showHint} = 1 if
		( defined $owner) &&
		( defined $::application) &&
		( $owner == $::application) &&
		( exists $p-> { ownerShowHint} ?
			$p-> { ownerShowHint} :
			$default-> { ownerShowHint}
		);

	$p-> {enabled} = $owner-> enabled
		if defined $owner && $owner-> autoEnableChildren;

	(my $cls = ref $self) =~ s/^Prima:://;

	for my $fore (qw(color hiliteBackColor disabledColor dark3DColor)) {
		unless (exists $p-> {$fore}) {
			my $clr = Prima::Widget::fetch_resource(
				$cls, $name, 'Foreground',
				$fore, $owner, fr::Color
			);
			$p-> {$fore} = $clr if defined $clr;
		}
	}
	for my $back (qw(backColor hiliteColor disabledBackColor light3DColor)) {
		unless (exists $p-> {$back}) {
			my $clr = Prima::Widget::fetch_resource(
				$cls, $name, 'Background',
				$back, $owner, fr::Color
			);
			$p-> {$back} = $clr if defined $clr;
		}
	}
	for my $fon (qw(font popupFont)) {
		my $f = Prima::Widget::fetch_resource(
			$cls, $name, 'Font', $fon, $owner, fr::Font);
		next unless defined $f;
		unless ( exists $p-> {$fon}) {
			$p-> {$fon} = $f;
		} else {
			for ( keys %$f) {
				$p-> {$fon}-> {$_} = $$f{$_}
					unless exists $p-> {$fon}-> {$_};
			}
		}
	}

	for ( $owner ? qw( color backColor showHint hint font): ()) {
		my $o_ = 'owner' . ucfirst $_;
		$p-> { $_} = $owner-> $_() if
			( $p-> { $o_} = exists $p-> { $_} ? 0 :
				( exists $p-> { $o_} ? $p-> { $o_} : $default-> {$o_}));
	}
	for ( qw( font popupFont)) {
		$p-> { $_} = {} unless exists $p-> { $_};
		$p-> { $_} = Prima::Widget-> font_match( $p-> { $_}, $default-> { $_});
	}

	if ( exists( $p-> { origin})) {
		$p-> { left  } = $p-> { origin}-> [ 0];
		$p-> { bottom} = $p-> { origin}-> [ 1];
	}

	if ( exists( $p-> { rect})) {
		my $r = $p-> { rect};
		$p-> { left  } = $r-> [ 0];
		$p-> { bottom} = $r-> [ 1];
		$p-> { right } = $r-> [ 2];
		$p-> { top   } = $r-> [ 3];
	}

	if ( exists( $p-> { size})) {
		$p-> { width } = $p-> { size}-> [ 0];
		$p-> { height} = $p-> { size}-> [ 1];
	}

	my $designScale = exists $p-> {designScale} ? $p-> {designScale} : $default-> {designScale};
	if ( defined $designScale) {
		my @defScale = @$designScale;
		if (( $defScale[0] > 0) && ( $defScale[1] > 0)) {
			@{$p-> { designScale}} = @defScale;
			for ( qw ( left right top bottom width height)) {
				$p-> {$_} = $default-> {$_}
					unless exists $p-> {$_};
			}
		} else {
			@defScale = $owner-> designScale
				if defined $owner && $owner-> scaleChildren;
			@{$p-> { designScale}} = @defScale
				if ( $defScale[0] > 0) && ( $defScale[1] > 0);
		}
		if ( exists $p-> { designScale}) {
			my @d = @{$p-> { designScale}};
			unless ( @default_font_box) {
				my $f = $::application-> get_default_font;
				@default_font_box = ( $f-> { width}, $f-> { height});
			}
			my @a = @default_font_box;
			$p-> {left}    *= $a[0] / $d[0] if exists $p-> {left};
			$p-> {right}   *= $a[0] / $d[0] if exists $p-> {right};
			$p-> {top}     *= $a[1] / $d[1] if exists $p-> {top};
			$p-> {bottom}  *= $a[1] / $d[1] if exists $p-> {bottom};
			$p-> {width}   *= $a[0] / $d[0] if exists $p-> {width};
			$p-> {height}  *= $a[1] / $d[1] if exists $p-> {height};
		}
	} else {
		$p-> {designScale} = [0,0];
	}


	$p-> { top} = $default-> { bottom} + $p-> { height}
		if ( !exists ( $p-> { top}) && !exists( $p-> { bottom}) && exists( $p-> { height}));
	$p-> { height} = $p-> { top} - $p-> { bottom}
		if ( !exists( $p-> { height}) && exists( $p-> { top}) && exists( $p-> { bottom}));
	$p-> { top} = $p-> { bottom} + $p-> { height}
		if ( !exists( $p-> { top}) && exists( $p-> { height}) && exists( $p-> { bottom}));
	$p-> { bottom} = $p-> { top} - $p-> { height}
		if ( !exists( $p-> { bottom}) && exists( $p-> { height}) && exists( $p-> { top}));
	$p-> { bottom} = $p-> { top} - $default-> { height}
		if ( !exists( $p-> { bottom}) && !exists( $p-> { height}) && exists( $p-> { top}));
	$p-> { top} = $p-> { bottom} + $default-> { height}
		if ( !exists( $p-> { top}) && !exists( $p-> { height}) && exists( $p-> { bottom}));


	$p-> { right} = $default-> { left} + $p-> { width}
		if ( !exists( $p-> { right}) && !exists( $p-> { left}) && exists( $p-> { width}));
	$p-> { width} = $p-> { right} - $p-> { left}
		if ( !exists( $p-> { width}) && exists( $p-> { right}) && exists( $p-> { left}));
	$p-> { right} = $p-> { left} + $p-> { width}
		if ( !exists( $p-> { right}) && exists( $p-> { width}) && exists( $p-> { left}));
	$p-> { left}  = $p-> { right} - $p-> { width}
		if ( !exists( $p-> { left}) && exists( $p-> { right}) && exists( $p-> { width}));
	$p-> { left}  = $p-> { right} - $default-> {width}
		if ( !exists( $p-> { left}) && !exists( $p-> { width}) && exists($p-> {right}));
	$p-> { right} = $p-> { left} + $default-> { width}
		if ( !exists( $p-> { right}) && !exists( $p-> { width}) && exists( $p-> { left}));

	if ( $p-> { popup}) {
		$p-> { popupItems} = $p-> {popup}-> get_items('');
		delete $p-> {popup};
	}

	my $current = exists $p-> { current} ? $p-> { current} : $default-> { current};
	if ( defined($owner) && !$current && !$owner-> currentWidget) {
		my $e = exists $p-> { enabled} ? $p-> { enabled} : $default-> { enabled};
		my $v = exists $p-> { visible} ? $p-> { visible} : $default-> { visible};
		$p-> {current} = 1 if $e && $v;
	}

	if ( exists $p-> {pointer}) {
		my $pt = $p-> {pointer};
		$p-> {pointerType}    = ( ref($pt) ? cr::User : $pt)
			if !exists $p-> {pointerType};
		$p-> {pointerIcon}    = $pt
			if !exists $p-> {pointerIcon} && ref( $pt);
		$p-> {pointerHotSpot} = $pt-> {__pointerHotSpot}
			if !exists $p-> {pointerHotSpot} && ref( $pt) && exists $pt-> {__pointerHotSpot};
	}

	if ( exists $p-> {pack}) {
		for ( keys %{$p-> {pack}}) {
			s/^-//; # Tk syntax
			$p-> {packInfo}-> {$_} = $p-> {pack}-> {$_}
				unless exists $p-> {packInfo}-> {$_};
		}
		$p-> {geometry} = gt::Pack unless exists $p-> {geometry};
	}
	$p-> {packPropagate} = 0 if !exists $p-> {packPropagate} &&
		( exists $p-> {width} || exists $p-> {height});

	if ( exists $p-> {place}) {
		for ( keys %{$p-> {place}}) {
			s/^-//; # Tk syntax
			$p-> {placeInfo}-> {$_} = $p-> {place}-> {$_}
				unless exists $p-> {placeInfo}-> {$_};
		}
		$p-> {geometry} = gt::Place unless exists $p-> {geometry};
	}
}

sub capture               {($#_)?shift-> set_capture     (@_)   :return $_[0]-> get_capture;     }
sub centered              {($#_)?$_[0]-> set_centered(1,1)      :$_[0]-> raise_wo("centered");   }
sub dark3DColor           {return shift-> colorIndex( ci::Dark3DColor , @_)};
sub disabledBackColor     {return shift-> colorIndex( ci::Disabled    , @_)};
sub disabledColor         {return shift-> colorIndex( ci::DisabledText, @_)};
sub hiliteBackColor       {return shift-> colorIndex( ci::Hilite      , @_)};
sub hiliteColor           {return shift-> colorIndex( ci::HiliteText  , @_)};
sub light3DColor          {return shift-> colorIndex( ci::Light3DColor, @_)};
sub popupFont             {($#_)?$_[0]-> set_popup_font ($_[1])  :return Prima::Font-> new($_[0], "get_popup_font", "set_popup_font")}
sub popupColor            { return shift-> popupColorIndex( ci::NormalText  , @_)};
sub popupBackColor        { return shift-> popupColorIndex( ci::Normal      , @_)};
sub popupDisabledBackColor{ return shift-> popupColorIndex( ci::Disabled    , @_)};
sub popupHiliteBackColor  { return shift-> popupColorIndex( ci::Hilite      , @_)};
sub popupDisabledColor    { return shift-> popupColorIndex( ci::DisabledText, @_)};
sub popupHiliteColor      { return shift-> popupColorIndex( ci::HiliteText  , @_)};
sub popupDark3DColor      { return shift-> popupColorIndex( ci::Dark3DColor , @_)};
sub popupLight3DColor     { return shift-> popupColorIndex( ci::Light3DColor, @_)};

sub x_centered       {($#_)?$_[0]-> set_centered(1,0)      :$_[0]-> raise_wo("x_centered"); }
sub y_centered       {($#_)?$_[0]-> set_centered(0,1)      :$_[0]-> raise_wo("y_centered"); }

sub insert
{
	my $self = shift;
	my @e;
	while (ref $_[0]) {
		my $cl = shift @{$_[0]};
		$cl = "Prima::$cl"
			unless $cl =~ /^Prima::/ || $cl-> isa("Prima::Component");
		push @e, $cl-> create(@{$_[0]}, owner=> $self);
		shift;
	}
	if (@_) {
		my $cl = shift @_;
		$cl = "Prima::$cl"
			unless $cl =~ /^Prima::/ || $cl-> isa("Prima::Component");
		push @e, $cl-> create(@_, owner=> $self);
	}
	return wantarray ? @e : $e[0];
}

#  The help context string is a pod-styled link ( see perlpod ) :
#  "file/section". If the widget's helpContext begins with /,
#  it's clearly a sub-topic, and the leading content is to be
#  extracted up from the hierarchy. When a grouping widget
#  does not have any help file related to, and does not wish that
#  its childrens' helpContext would be combined with the upper
#  helpContext, an empty string " " can be set

sub help
{
	my $self = $_[0];
	my $ht = $self-> helpContext;
	return 0 if $ht =~ /^\s+$/;
	if ( length($ht) && $ht !~ m[^/]) {
		$::application-> open_help( $ht);
		return 1;
	}
	my $file;
	while ( $self = $self-> owner) {
		my $ho = $self-> helpContext;
		return 0 if $ho =~ /^\s+$/;
		if ( length($ht) && $ht !~ /^\//) {
			$file = $ht;
			last;
		}
	}
	return 0 unless defined $file;
	$file .= '/' unless $file =~ /\/$/;
	$::application-> open_help( $file . $ht);
}

sub pointer
{
	if ( $#_) {
		$_[0]-> pointerType( $_[1]), return unless ref( $_[1]);
		defined $_[1]-> {__pointerHotSpot} ?
			$_[0]-> set(
				pointerIcon    => $_[1],
				pointerHotSpot => $_[1]-> {__pointerHotSpot},
			) :
			$_[0]-> pointerIcon( $_[1]);
		$_[0]-> pointerType( cr::User);
	} else {
		my $i = $_[0]-> pointerType;
		return $i if $i != cr::User;
		$i = $_[0]-> pointerIcon;
		$i-> {__pointerHotSpot} = [ $_[0]-> pointerHotSpot];
		return $i;
	}
}

sub widgets
{
	return shift-> get_widgets unless $#_;
	my $self = shift;
	return unless $_[0];
	$self-> insert(($#_ or ref($_[0]) ne 'ARRAY') ? @_ : @{$_[0]});
}

sub key_up      { splice( @_,5,0,1) if $#_ > 4; shift-> key_event( cm::KeyUp, @_)}
sub key_down    { shift-> key_event( cm::KeyDown, @_)}
sub mouse_up    { splice( @_,5,0,0) if $#_ > 4; shift-> mouse_event( cm::MouseUp, @_); }
sub mouse_move  { splice( @_,5,0,0) if $#_ > 4; splice( @_,1,0,0); shift-> mouse_event( cm::MouseMove, @_) }
sub mouse_enter { splice( @_,5,0,0) if $#_ > 4; splice( @_,1,0,0); shift-> mouse_event( cm::MouseEnter, @_) }
sub mouse_leave { shift-> mouse_event( cm::MouseLeave ) }
sub mouse_wheel { splice( @_,5,0,0) if $#_ > 4; shift-> mouse_event( cm::MouseWheel, @_) }
sub mouse_down  { splice( @_,5,0,0) if $#_ > 4;
						splice( @_,2,0,0) if $#_ < 4;
						shift-> mouse_event( cm::MouseDown, @_);}
sub mouse_click { shift-> mouse_event( cm::MouseClick, @_) }
sub select      { $_[0]-> selected(1); }
sub deselect    { $_[0]-> selected(0); }
sub focus       { $_[0]-> focused(1); }
sub defocus     { $_[0]-> focused(0); }

# Tk namespace and syntax compatibility

sub __tk_dash_map
{
	my %ret;
	my %hash = @_;
	while ( my ( $k, $v ) = each %hash ) {
		$k =~ s/^-//;
		$ret{$k} = $v;
	}
	return %ret;
}

sub pack {
	my $self = shift;
	$self-> packInfo( { __tk_dash_map(@_) });
	$self-> geometry( gt::Pack);
}

sub place {
	my $self = shift;
	$self-> placeInfo( { __tk_dash_map(@_) });
	$self-> geometry( gt::Place);
}

sub packForget { $_[0]-> geometry( gt::Default) if $_[0]-> geometry == gt::Pack }
sub placeForget { $_[0]-> geometry( gt::Default) if $_[0]-> geometry == gt::Place }
sub packSlaves { shift-> get_pack_slaves()}
sub placeSlaves { shift-> get_place_slaves()}

sub rect_bevel
{
	my ( $self, $canvas, $x, $y, $x1, $y1, %opt) = @_;

	my $width = $opt{width} || 0;
	my @c3d   = ( $opt{concave} || $opt{panel}) ?
		( $self-> dark3DColor, $self-> light3DColor) :
		( $self-> light3DColor, $self-> dark3DColor);
	my $fill  = $opt{fill};

	return $canvas-> rect3d( $x, $y, $x1, $y1, $width, @c3d, $fill)
		if $width < 2;
	my $back  = (defined($fill) && !ref($fill)) ? $fill : $self-> backColor;

	# 0 - upper left under 2 -- inner square
	# 1 - lower right over 3
	# 2 - upper left         -- outer square
	# 3 - lower right
	if ( $opt{concave}) {
		push @c3d, 0x404040, $c3d[0];
	} elsif ( $opt{panel}) {
		@c3d = ( 0x404040, $self-> disabledBackColor, $c3d[0], $c3d[1]);
	} else {
		push @c3d, $c3d[1], 0x404040;
	}

	$fill = $fill->clone( widgetClass => $self->widgetClass ) if $fill && ref($fill);

	my $hw = int( $width / 2);
	$canvas-> rect3d( $x, $y, $x1, $y1, $hw, @c3d[2,3], $fill);
	$canvas-> rect3d( $x + $hw, $y + $hw, $x1 - $hw, $y1 - $hw, $width - $hw, @c3d[0,1]);
}

sub has_alpha_layer { $_[0]-> layered && $_[0]-> is_surface_layered }

sub begin_drag
{
	my ( $self, @opt ) = @_;
	my %opt;
	if ( 1 != @opt ) {
		%opt = @opt;
	} elsif ( ref($opt[0]) && $opt[0]->isa('Prima::Image')) {
		$opt{image} = $opt[0];
	} else {
		$opt{text} = $opt[0];
	}

	my $actions = ($opt{actions} // dnd::Copy) & dnd::Mask;
	unless ( $actions ) {
		Carp::carp("bad actions");
		return -1;
	}

	# don't start dragging immediately
	if ( $opt{track} // 1 ) {
		my @start_pos = $self->pointerPos;
		my $offset = $opt{track} // 5;
		my $break  = 0;
		my @id;
		push @id, $self-> add_notification( MouseMove => sub {
			my ( undef, undef, $x, $y ) = @_;
			$break = 1 if
				abs( $start_pos[0] - $x ) > $offset || 
				abs( $start_pos[1] - $y ) > $offset;
		});
		push @id, 
			map { $self-> add_notification( $_ => sub { $break = -1 }) }
			qw(MouseLeave MouseClick MouseDown MouseUp Destroy);
		1 while !$break && $::application->yield(1);
		return dnd::None unless $self->alive;
		$self->remove_notification($_) for @id;
		return -1 if $break < 0;
	}

	# data
	my $clipboard = $::application->get_dnd_clipboard;
	if ( exists $opt{text}) {
		$clipboard->text($opt{text});
		$opt{preview} //= $opt{text};
	} elsif ( exists $opt{image}) {
		$clipboard->image($opt{image});
		$opt{preview} //= $opt{image};
	} elsif ( exists $opt{format} and exists $opt{data}) {
		$clipboard->copy($opt{format}, $opt{data});
	} # or else you fill the clipboard yourself

	my @id;
	my %pointers;
	my $last_action = -1;
	$opt{preview} = undef unless $::application->get_system_value(sv::ColorPointer);

	my @max = map { $_ / 8 } $::application->size;
	if ( $opt{preview} && !ref($opt{preview}) ) {
		my @lines = split "\n", $opt{preview};
		my $fh    = $self->font->height;
		my @sz = ( 0, 10 + $fh * @lines );
		for my $text ( @lines ) {
			my $tw = $self->get_text_width($text, 1);
			$sz[0] = $tw if $sz[0] < $tw;
		}
		$sz[0] += 10;
		$sz[0] = $max[0] if $sz[0] > $max[0];
		$sz[1] = $max[1] if $sz[1] > $max[1];
		my $i = Prima::Icon->new(
			size      => \@sz,
			type      => im::RGB,
			color     => $self->color,
			backColor => $self->backColor,
			font      => $self->font,
			autoMasking => am::None,
			maskType    => im::bpp8,
		);
		$i->begin_paint;
		$i->clear;
		my $y = $i->height - $fh - 5;
		for my $text ( @lines ) {
			$i->text_out( $text, 5, $y);
			$y -= $fh;
		}
		$i->end_paint;
		$i->alpha(160, 0, 0, $i->size);
		$opt{preview} = $i;
	}

	if ( my $p = $opt{preview}) {
		my @sz = $p->size;
		$opt{preview} = $p->extract(0, 0,
			($sz[0] > $max[0]) ? $max[0] : $sz[0],
			($sz[1] > $max[1]) ? $max[1] : $sz[1],
		) if $sz[0] > $max[0] || $sz[1] > $max[1];
	}

	# select multi actions
	unless (dnd::is_one_action($actions)) {
		my $default_action = dnd::to_one_action($actions);
		push @id, $self-> add_notification( DragQuery => sub {
			my ( $self, $modmap, $counterpart, $ref ) = @_;
			if ( $modmap & km::Ctrl and $actions & dnd::Move ) {
				$ref->{action} = dnd::Move;
			} elsif ( $modmap & km::Shift and $actions & dnd::Link ) {
				$ref->{action} = dnd::Link;
			} else {
				$ref->{action} = $default_action;
			}
		});
	}

	# update pointers
	push @id, $self-> add_notification( DragResponse => sub {
		my ( undef, $allow, $action, $counterpart ) = @_;

		unless ($pointers{$action}) {
			$self->pointer(dnd::pointer($action));
			my $p = $opt{preview};
			my $i = $self->pointerIcon;
			my @hs = $self->pointerHotSpot;
			$hs[1] += $p->height;
			my $n = Prima::Icon->new(
				type     => im::RGB,
				maskType => im::bpp8,
				autoMasking => am::None,
				size     => [ $i->width + $p->width, $i-> height + $p-> height ],
			);
			$i->autoMasking(am::None);
			$i->type(im::RGB);
			$i->maskType(8);
			$p->maskType(8)
				if $p->isa('Prima::Icon');
			$n->put_image( 0, $p->height, $i, rop::SrcCopy);
			$n->put_image( $i->width, 0, $p, rop::SrcCopy);
			$n->alpha(0xff, $i->width, 0, $i->width + $p->width - 1, $p->height - 1)
				if !$p->isa('Prima::Icon');
			$n->{__pointerHotSpot} = \@hs;
			$pointers{$action} = $n;
		}
		if ($action != $last_action) {
			$last_action = $action;
			$self->pointer($pointers{$action});
		}
	}) if $opt{preview};

	my $old_dndAware;
	if ( !( $opt{self_aware} // 1) ) {
		$old_dndAware = $self->dndAware;
		$self->dndAware(0);
	}
	my $pointer = $self->pointer;
	my @opp = $::application->pointerPos;
	my ($ret, $counterpart) = $self->dnd_start($actions, !$opt{preview});
	if ( $self->alive ) {
		if ( $ret == dnd::None && $opt{preview} ) {
			my @npp = $::application->pointerPos;
			my $paint_flag = 0;
			my $flyback = Prima::Widget->new(
				size      => [ $opt{preview}->size ],
				origin    => \@npp,
				layered   => 1,
				backColor => 0,
				syncPaint => 1,
				onPaint   => sub {
					$_[0]->clear;
					$_[0]->put_image(0,0,$opt{preview});
					$paint_flag = 1;
				}
			);
			$flyback->bring_to_front;
			my @targ = map { $_ / 2 } $flyback->size;
			while (abs( $npp[0] - $opp[0]) > $targ[0] || abs($npp[1] - $opp[1]) > $targ[1]) {
				@npp = map { ( $npp[$_] + $opp[$_] ) / 2 } 0, 1;
				my $max_wait = 10;
				$::application->yield while !$paint_flag && $max_wait--;
				$paint_flag = 0;
				CORE::select(undef, undef, undef, 0.1);
				$flyback->origin(@npp);
				$flyback->bring_to_front;
			}
			$flyback->destroy;
		}
		$self->pointer($pointer); # dnd_start doesn't affect children pointers and doesn't restore them
		$self->remove_notification($_) for @id;
		$self->dndAware($old_dndAware) if $old_dndAware;
	}
	return wantarray ? ($ret, $counterpart) : $ret;
}

package Prima::Window;
use vars qw(@ISA);
@ISA = qw(Prima::Widget);

{
my %RNT = (
	%{Prima::Widget-> notification_types()},
	Activate      => nt::Default,
	Deactivate    => nt::Default,
	EndModal      => nt::Default,
	Execute       => nt::Default,
	WindowState   => nt::Default,
);

sub notification_types { return \%RNT; }
}

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		borderIcons           => bi::All,
		borderStyle           => bs::Sizeable,
		clipOwner             => 0,
		growMode              => gm::DontCare,
		effects               => undef,
		icon                  => 0,
		mainWindow            => 0,
		menu                  => undef,
		menuItems             => undef,
		menuColor             => cl::NormalText,
		menuBackColor         => cl::Normal,
		menuHiliteColor       => cl::HiliteText,
		menuHiliteBackColor   => cl::Hilite,
		menuDisabledColor     => cl::DisabledText,
		menuDisabledBackColor => cl::Disabled,
		menuLight3DColor      => cl::Light3DColor,
		menuDark3DColor       => cl::Dark3DColor,
		menuFont              => $_[ 0]-> get_default_menu_font,
		modalResult           => mb::Cancel,
		modalHorizon          => 1,
		onTop                 => 0,
		ownerIcon             => 1,
		originDontCare        => 1,
		sizeDontCare          => 1,
		tabStop               => 0,
		taskListed            => 1,
		transparent           => 0,
		widgetClass           => wc::Window,
		windowState           => ws::Normal,
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub profile_check_in
{
	my ( $self, $p, $default) = @_;

	my $shp = exists $p-> {originDontCare} ? $p-> {originDontCare} : $default-> {originDontCare};
	my $shs = exists $p-> {sizeDontCare  } ? $p-> {sizeDontCare  } : $default-> {sizeDontCare  };
	$p-> {originDontCare} = 0 if $shp and
		exists $p-> {left}   or exists $p-> {bottom} or
		exists $p-> {origin} or exists $p-> {rect} or
		exists $p-> {top}    or exists $p-> {right};
	$p-> {sizeDontCare} = 0 if $shs and
		exists $p-> {width}  or exists $p-> {height} or
		exists $p-> {size}   or exists $p-> {rect} or
		exists $p-> {right}  or exists $p-> {top};

	$self-> SUPER::profile_check_in( $p, $default);

	if ( $p-> { menu}) {
		$p-> { menuItems} = $p-> {menu}-> get_items("");
		delete $p-> {menu};
	}
	$p-> { menuFont} = {}
		unless exists $p-> { menuFont};
	$p-> { menuFont} = Prima::Drawable-> font_match( $p-> { menuFont}, $default-> { menuFont});

	$p-> { modalHorizon} = 0
		if $p-> {clipOwner} || $default-> {clipOwner};

	$p-> { growMode} = 0
		if !exists $p-> {growMode}
		and $default-> {growMode} == gm::DontCare
		and (
			( exists $p-> {clipOwner} && ($p-> {clipOwner}==1))
			or ( $default-> {clipOwner} == 1)
		);

	my $owner = exists $p-> { owner} ? $p-> { owner} : $default-> { owner};
	if ( $owner) {
		$p-> {icon} = $owner-> icon if
			( $p-> {ownerIcon} = exists $p-> {icon} ?
				0 :
				( exists $p-> {ownerIcon} ?
					$p-> {ownerIcon} :
					$default-> {ownerIcon}
				)
			);
	}
}

sub maximize    { $_[0]-> windowState( ws::Maximized)}
sub minimize    { $_[0]-> windowState( ws::Minimized)}
sub restore     { $_[0]-> windowState( ws::Normal)}

sub frameWidth           {($#_)?$_[0]-> frameSize($_[1], ($_[0]-> frameSize)[1]):return ($_[0]-> frameSize)[0];  }
sub frameHeight          {($#_)?$_[0]-> frameSize(($_[0]-> frameSize)[0], $_[1]):return ($_[0]-> frameSize)[1];  }
sub menuFont             {($#_)?$_[0]-> menuFont   ($_[1])  :return Prima::Font-> new($_[0], "get_menu_font", "set_menu_font")}
sub menuColor            { return shift-> menuColorIndex( ci::NormalText   , @_);}
sub menuBackColor        { return shift-> menuColorIndex( ci::Normal       , @_);}
sub menuDisabledBackColor{ return shift-> menuColorIndex( ci::Disabled     , @_);}
sub menuHiliteBackColor  { return shift-> menuColorIndex( ci::Hilite       , @_);}
sub menuDisabledColor    { return shift-> menuColorIndex( ci::DisabledText , @_);}
sub menuHiliteColor      { return shift-> menuColorIndex( ci::HiliteText   , @_);}
sub menuDark3DColor      { return shift-> menuColorIndex( ci::Dark3DColor  , @_);}
sub menuLight3DColor     { return shift-> menuColorIndex( ci::Light3DColor , @_);}


package Prima::Dialog;
use vars qw(@ISA);
@ISA = qw(Prima::Window);

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		borderStyle    => bs::Dialog,
		borderIcons    => bi::SystemMenu | bi::TitleBar,
		widgetClass    => wc::Dialog,
		originDontCare => 0,
		sizeDontCare   => 0,
		taskListed     => 0,
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

package Prima::MainWindow;
use vars qw(@ISA);
@ISA = qw(Prima::Window);

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		mainWindow => 1,
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub on_create  { $::main_window = $_[0] }
sub on_destroy { $::application-> close; undef $::main_window }

package Prima::MenuItem;

sub create
{
	my $class = $_[0];
	my $self = {};
	bless( $self, $class);
	$self-> {menu} = $_[1];
	$self-> {id}   = $_[2];
	return $self;
}

sub new { shift-> create(@_) }
sub menu    { $_[0]->{menu} }

sub accel   { my $self = shift;return $self-> {menu}-> accel( $self-> {id}, @_);}
sub action  { my $self = shift;return $self-> {menu}-> action ( $self-> {id}, @_);}
sub autoToggle { my $self = shift;return $self-> {menu}-> autoToggle( $self-> {id}, @_);}
sub checked { my $self = shift;return $self-> {menu}-> checked( $self-> {id}, @_);}
sub enabled { my $self = shift;return $self-> {menu}-> enabled( $self-> {id}, @_);}
sub options { my $self = shift;return $self-> {menu}-> options( $self-> {id}, @_);}
sub image   { my $self = shift;return $self-> {menu}-> image  ( $self-> {id}, @_);}
sub icon    { my $self = shift;return $self-> {menu}-> icon   ( $self-> {id}, @_);}
sub key     { my $self = shift;return $self-> {menu}-> key    ( $self-> {id}, @_);}
sub submenu { my $self = shift;return $self-> {menu}-> submenu( $self-> {id}, @_);}
sub text    { my $self = shift;return $self-> {menu}-> text   ( $self-> {id}, @_);}
sub group   { my $self = shift;return $self-> {menu}-> group  ( $self-> {id}, @_);}
sub items   { my $i = shift; ( @_) ? $i-> { menu}-> set_items  ( $i-> { id}, @_):return $i-> {menu}-> get_items  ( $i-> { id}); }
sub enable  { $_[0]-> {menu}-> enabled( $_[0]-> { id}, 1) };
sub disable { $_[0]-> {menu}-> enabled( $_[0]-> { id}, 0) };
sub check   { $_[0]-> {menu}-> checked( $_[0]-> { id}, 1) };
sub uncheck { $_[0]-> {menu}-> checked( $_[0]-> { id}, 0) };
sub remove  { $_[ 0]-> {menu}-> remove( $_[0]-> { id}) }
sub toggle  {
	my $i = !$_[0]-> { menu}-> checked($_[0]-> { id});
	$_[0]-> { menu}-> checked($_[0]-> { id}, $i);
	return $i
}
sub id {
	return $_[0]->{id} unless $#_;
	$_[0]->menu->set_variable( $_[0]->{id}, $_[1] );
	$_[0]->{id} = $_[1];
}
sub execute  { $_[0]->{menu}->execute($_[0]->{id}) }
sub children { $_[0]->{menu}->get_children($_[0]->{id}) }
sub is_separator { $_[0]->{menu}->is_separator($_[0]->{id}) }
sub is_submenu   { $_[0]->{menu}->is_submenu($_[0]->{id}) }

sub check_icon_size { $::application->get_system_value(sv::MenuCheckSize) }

package Prima::AbstractMenu;
use vars qw(@ISA);
@ISA = qw(Prima::Component);

{
my %RNT = (
	%{Prima::Component-> notification_types()},
	Change      => nt::Default,
	ItemMeasure => nt::Action,
	ItemPaint   => nt::Action,
);

sub notification_types { return \%RNT; }
}

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		selected => 1,
		items    => undef
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub select     {$_[0]-> selected(1)}

sub enable     {$_[0]-> enabled($_[1],1);}
sub disable    {$_[0]-> enabled($_[1],0);}
sub check      {$_[0]-> checked($_[1],1);}
sub uncheck    {$_[0]-> checked($_[1],0);}
sub items      {($#_)?$_[0]-> set_items       ($_[1]):return $_[0]-> get_items("");      }
sub toggle     {
	my $i = !$_[0]-> checked($_[1]);
	$_[0]-> checked($_[1], $i);
	return $i;
}

sub AUTOLOAD
{
	no strict;
	my $self = shift;
	my $expectedMethod = $AUTOLOAD;
	die "There is no such method as \"$expectedMethod\""
		if scalar(@_) or not ref $self;
	my ($itemName) = $expectedMethod =~ /::([^:]+)$/;
	die "Unknown menu item identifier \"$itemName\""
		unless defined $itemName && $self-> has_item( $itemName);
	return Prima::MenuItem-> create( $self, $itemName);
}
sub on_itemmeasure
{
	my ( $self, $id, $ref) = @_;
	my $opt = $self->options($id) or return;
	return if ref($opt) ne 'HASH';
	if ( defined( my $cb = $opt->{onMeasure})) {
		$cb->($self, Prima::MenuItem->new($self, $id), $ref);
		$self->clear_event;
	}
}

sub on_itempaint
{
	my ( $self, $id, @r) = @_;
	my $opt = $self->options($id) or return;
	return if ref($opt) ne 'HASH';
	if ( defined( my $cb = $opt->{onPaint})) {
		$cb->($self, Prima::MenuItem->new($self, $id), @r);
		$self->clear_event;
	}
}


package Prima::AccelTable;
use vars qw(@ISA);
@ISA = qw(Prima::AbstractMenu);

package Prima::Menu;
use vars qw(@ISA);
@ISA = qw(Prima::AbstractMenu);

package Prima::Popup;
use vars qw(@ISA);
@ISA = qw(Prima::AbstractMenu);

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	$def-> {autoPopup} = 1;
	return $def;
}

package Prima::HintWidget;
use vars qw(@ISA);
@ISA = qw(Prima::Widget);

sub profile_default
{
	my $def = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		showHint      => 0,
		ownerShowHint => 0,
		visible       => 0,
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub on_change
{
	my $self = $_[0];
	my @ln = $self->text_split_lines($self->text);
	my $maxLn = 0;
	for ( @ln) {
		my $x = $self-> get_text_width( $_);
		$maxLn = $x if $maxLn < $x;
	}
	$self-> size(
		$maxLn + 6,
		( $self-> font-> height * scalar @ln) + 2
	);
}

sub on_paint
{
	my ($self,$canvas) = @_;
	my @size = $canvas-> size;
	$canvas-> clear( 1, 1, $size[0]-2, $size[1]-2);
	$canvas-> rectangle( 0, 0, $size[0]-1, $size[1]-1);
	my $fh = $canvas-> font-> height;
	my ( $x, $y) = ( 3, $size[1] - 1 - $fh);
	my @ln = $canvas->text_split_lines($self->text);
	for ( @ln) {
		$canvas-> text_out_bidi( $_, $x, $y);
		$y -= $fh;
	}
}

sub text
{
	return $_[0]-> SUPER::text unless $#_;
	my $self = $_[0];
	$self-> SUPER::text( $_[1]);
	$self-> notify( 'Change');
	$self-> repaint;
}

package Prima::Application;
use vars qw(@ISA @startupNotifications);
@ISA = qw(Prima::Widget);

{
my %RNT = (
	%{Prima::Widget-> notification_types()},
	FormatExists => nt::Action,
	Copy         => nt::Action,
	Paste        => nt::Action,
	Idle         => nt::Default,
);

sub notification_types { return \%RNT; }
}

my $unix = Prima::Application-> get_system_info-> {apc} == apc::Unix;

sub profile_default
{
	my $def  = $_[ 0]-> SUPER::profile_default;
	my %prf = (
		autoClose      => 0,
		pointerType    => cr::Arrow,
		pointerVisible => 1,
		icon           => undef,
		owner          => undef,
		scaleChildren  => 0,
		ownerColor     => 0,
		ownerBackColor => 0,
		ownerFont      => 0,
		ownerShowHint  => 0,
		ownerPalette   => 0,
		showHint       => 1,
		hintClass      => 'Prima::HintWidget',
		hintColor      => cl::Black,
		hintBackColor  => 0xffff80,
		hintPause      => 800,
		hintFont       => Prima::Widget::get_default_font,
		modalHorizon   => 1,
		printerClass   => $unix ? 'Prima::PS::Printer' : 'Prima::Printer',
		printerModule  => $unix ? 'Prima::PS::Printer' : '',
		helpClass      => 'Prima::HelpViewer',
		helpModule     => 'Prima::HelpViewer',
		uiScaling      => 0,
		wantUnicodeInput => 0,
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub profile_check_in
{
	my ( $self, $p, $default) = @_;
	$self-> SUPER::profile_check_in( $p, $default);
	delete $p-> { printerModule};
	delete $p-> { owner};
	delete $p-> { ownerColor};
	delete $p-> { ownerBackColor};
	delete $p-> { ownerFont};
	delete $p-> { ownerShowHint};
	delete $p-> { ownerPalette};
}

sub add_startup_notification
{
	shift if ref($_[0]) ne 'CODE'; # skip class reference, if any
	if ( $::application) {
		$_-> ($::application) for @_;
	} else {
		push( @startupNotifications, @_);
	}
}

sub setup
{
	my $self = $::application = shift;
	$self-> SUPER::setup;
	for my $clp (Prima::Clipboard-> get_standard_clipboards()) {
		$self-> {$clp} = $self-> insert( qw(Prima::Clipboard), name => $clp)
			unless exists $self-> {$clp};
	}
	$_-> ($self) for @startupNotifications;
	undef @startupNotifications;

	# setup image cliboard transfer routines specific to gtk
	if ( $unix ) {
		my %weights = (
			bmp  => 4,  # bmp is independent on codecs
			png  => 3,  # png is lossless
			tiff => 2,  # tiff is usually lossless
		);
		my %codecs  = map { lc($_-> {fileShortType})  => $_ } @{Prima::Image-> codecs};
		$_->{weight} = $weights{ lc($_-> {fileShortType}) } || 1 for values %codecs;
		my @codecs = map { {
			mime => "image/$_",
			id   => $codecs{$_}->{codecID},
		} } sort { $codecs{$b}->{weight} <=> $codecs{$a}->{weight} } keys %codecs;
		my $clipboard = $self-> Clipboard;
		$clipboard-> register_format($_->{mime}) for @codecs;
		$self-> {GTKImageClipboardFormats} = \@codecs;
	}
}

sub get_fullscreen_image
{
	my $self = shift;
	if ( $^O eq 'darwin') {
		require Prima::sys::XQuartz;
		return Prima::sys::XQuartz::get_fullscreen_image($self);
	} else {
		return $self->get_image(0,0,$self->size);
	}
}

sub get_printer
{
	unless ( $_[0]-> {Printer}) {
		if ( length $_[0]-> {PrinterModule}) {
			eval 'use ' . $_[0]-> {PrinterModule} . ';';
			die "$@" if $@;
		}
		$_[0]-> {Printer} = $_[0]-> {PrinterClass}-> create( owner => $_[0]);
	}
	return $_[0]-> {Printer};
}

sub hintFont      {($#_)?$_[0]-> set_hint_font        ($_[1])  :return Prima::Font-> new($_[0], "get_hint_font", "set_hint_font")}
sub helpModule    {($#_)?$_[0]-> {HelpModule} = $_[1] : return $_[0]-> {HelpModule}}
sub helpClass     {($#_)?$_[0]-> {HelpClass}  = $_[1] : return $_[0]-> {HelpClass}}

sub help_init
{
	return 0 unless length $_[0]-> {HelpModule};
	eval 'use ' . $_[0]-> {HelpModule} . ';';
	die "$@" if $@;
	return 1;
}

sub close_help
{
	return '' unless $_[0]-> help_init;
	shift-> {HelpClass}-> close;
}

sub open_help
{
	my ( $self, $link) = @_;
	return unless length $link;
	return unless $self-> help_init;
	return $self-> {HelpClass}-> open($link);
}

sub on_copy
{
	my ( $self, $format, $clipboard, $data ) = @_;
	$clipboard-> store( $format, $data);
	if ( $format eq 'Image') {
		if ( my $formats = $self-> {GTKImageClipboardFormats} ) {
			my ($bmp, $bits, $handle) = ($formats->[0], '');
			if (open( $handle, '>', \$bits) and $data->save($handle, codecID => $bmp->{id})) {
				$clipboard->store($bmp->{mime}, $bits);
			}
		}
	}
}

sub on_formatexists
{
	my ( $self, $format, $clipboard, $ref) = @_;
	
	if ( $format eq 'Text') {
		if ( $self-> wantUnicodeInput) {
			return $$ref = 'UTF8' if $clipboard-> format_exists( 'UTF8');
		}
		$$ref = $clipboard-> format_exists( $format ) ? $format : undef;
	} elsif ( $format eq 'Image') {
		$$ref = undef;
		return $$ref = 'Image' if $clipboard-> format_exists( 'Image');
		my $codecs = $self-> {GTKImageClipboardFormats} or return;
		my %formats = map { $_ => 1 } $clipboard-> get_formats;
		my @codecs  = grep { $formats{$_->{mime}} } @$codecs or return;
		$$ref = $codecs[0]->{mime} if $clipboard-> format_exists($codecs[0]->{mime});
	} else {
		$$ref = $clipboard-> format_exists( $format ) ? $format : undef;
	}
	undef;
}

sub on_paste
{
	my ( $self, $format, $clipboard, $ref) = @_;
	
	if ( $format eq 'Text') {
		if ( $self-> wantUnicodeInput) {
			return if defined ( $$ref = $clipboard-> fetch( 'UTF8'));
		}
		$$ref = $clipboard-> fetch( 'Text');
	} elsif ( $format eq 'Image') {
		$$ref = $clipboard-> fetch( 'Image');
		return if defined $$ref;

		my $codecs = $self-> {GTKImageClipboardFormats};
		return unless $codecs;

		my %formats = map { $_ => 1 } $clipboard-> get_formats;
		my @codecs  = grep { $formats{$_->{mime}} } @$codecs;
		return unless @codecs;

		my $data = $clipboard-> fetch($codecs[0]->{mime});
		return unless defined $data;

		my $handle;
		open( $handle, '<', \$data) or return;

		local $@;
		$$ref = Prima::Image-> load($handle, loadExtras => 1 );
	} else {
		$$ref = $clipboard-> fetch( $format);
	}
	undef;
}

1;

=pod

=head1 NAME

Prima::Classes - binder module for the built-in classes.

=head1 DESCRIPTION

C<Prima::Classes> and L<Prima::Const> is a minimal set of perl modules needed for
the toolkit. Since the module provides bindings for the core classes, it is required
to be included in every Prima-related module and program.

=head1 AUTHOR

Dmitry Karasik, E<lt>dmitry@karasik.eu.orgE<gt>.

=head1 SEE ALSO

L<Prima>, L<Prima::Const>


=cut

