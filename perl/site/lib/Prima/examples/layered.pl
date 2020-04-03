use strict;
use warnings;
use Prima qw(Application Buttons);

my $j = Prima::Image->new(
	width => 100,
	height => 100,
	type => im::Byte,
);
$j->begin_paint;
$j->backColor(cl::Clear);
$j->clear;
$j->new_gradient(palette => [cl::Black, cl::White])->ellipse(50, 50, 100, 100);
$j->end_paint;
$j->type(im::Byte);

sub icon
{
	my $color =  shift;
	my $i = Prima::Image->new(
		width => 100,
		height => 100,
		type => im::RGB,
	);
	$i->begin_paint;
	$i->backColor(cl::Clear);
	$i->clear;
	$i->new_gradient(
		palette => [cl::Black, $color],
		spline  => [0.2,0.8],
	)-> ellipse( 50, 50, 100, 100 );
	$i->end_paint;

	my $k = Prima::Icon->new;
	$k->combine($i, $j);

	my $db = Prima::DeviceBitmap->new(
		width  => 160,
		height => 160,
		type   => dbt::Layered,
	);

	$db->backColor(cl::Clear);
	$db->clear;
	$db->stretch_image( 0, 0, 160, 160, $k);

	return $db;
}

my ( $r, $g, $b ) = map { icon($_) } (cl::LightRed, cl::LightGreen, cl::LightBlue);

my $angle = 0;
my $pi = 3.14159;

my $i = Prima::Region-> new( box => [ 0, 0,
	96 * $::application-> font-> width  / 7,  # poor man's calculations of
	36 * $::application-> font-> height / 16, # button size
]);

$i-> combine( Prima::Drawable->new_path->ellipse( 10, 10, 10 )->region, rgnop::Diff);

my $w = Prima::MainWindow->new(
	layered  => 1,
	text     => 'ARGB example',
	size     => [ 300, 300 ],
	origin   => [ 100, 100 ],
	backColor => cl::Black,
	menuItems  => [
		[ '~Options' => [
			[ '*layered' => 'La~yered' => 'Ctrl+Y' => '^Y' => sub {
				my $self = shift;
				$self-> layered( $self-> menu-> toggle(shift) );
			} ],
		]],
	],
	onPaint   => sub {
		my $self = shift;
		$self->clear;
		my ($w, $h) = $self->size;
		$self->color(cl::LightRed);
		$self->rectangle(4,4,$w-4,$h-4);
		my $x = $w * 1 / 2;
		my $y = $h * 1 / 2;

		$self->translate($w/2, $h/2);
		my ( $x0, $y0 ) = ( $w/12, $h/12);
		my $r0 = ($x0 < $y0) ? $x0 : $y0;
		my $a = 0;
		for my $i ( $r, $g, $b ) {
			my $sin = sin($a) * $r0;
			my $cos = cos($a) * $r0;
			my $xx = $cos - $sin;
			my $yy = $sin + $cos;
			$xx -= $x / 2;
			$yy -= $y / 2;
			$self->stretch_image( $xx, $yy, $x, $y, $i);
			$a += $pi * 2 / 3;
		}
	}
);

my $btn = $w-> insert( Button =>
	origin  => [10,10],
	shape   => $i,
	text    => '~Quit',
	onClick => sub { $::application-> close },
);

$btn->insert( Widget =>
	origin => [10,10],
	size   => [10,10],
	onPaint => sub {
	   my $self = shift;
	   $self->clipRect(-1000,-1000,2000,2000);
	   $self->color(cl::LightRed);
	   $self->bar(-1000,-1000,2000,2000);
	   $self->color(cl::White);
	   $self->bar(0,0,$self->width-1,$self->height-1);
	   $self->color(cl::LightGreen);
	   $self->rectangle(0,0,$self->width-1,$self->height-1);
	},
);

my $widget = Prima::Widget->new(
	layered  => 1,
	buffered => 1,
	size     => [ 300, 300 ],
	origin   => [ 100, 100 ],
	backColor => cl::Black,
	selectable => 1,
	onMouseDown => sub {
		$_[0]-> {drag}    = [ $_[3], $_[4]];
		$_[0]-> {lastPos} = [ $_[0]-> left, $_[0]-> bottom];
		$_[0]-> capture(1);
		$_[0]-> repaint;
	},
	onMouseMove => sub{
		return unless exists $_[0]-> { drag};
		my @org = $_[0]-> origin;
		my @st  = @{$_[0]-> {drag}};
		my @new = ( $org[0] + $_[2] - $st[0], $org[1] + $_[3] - $st[1]);
		$_[0]-> origin( $new[0], $new[1]) if $org[1] != $new[1] || $org[0] != $new[0];
	},
	onMouseUp => sub {
		$_[0]-> capture(0);
		delete $_[0]-> {drag};
	},
	onPaint   => sub {
		my $self = shift;
		$self->clear;
		my ($w, $h) = $self->size;
		my $x = $w * 1 / 2;
		my $y = $h * 1 / 2;

		$self->translate($w/2, $h/2);
		my ( $x0, $y0 ) = ( $w/12, $h/12);
		my $r0 = ($x0 < $y0) ? $x0 : $y0;
		my $a = $angle;
		for my $i ( $r, $g, $b ) {
			my $sin = sin($a) * $r0;
			my $cos = cos($a) * $r0;
			my $xx = $cos - $sin;
			my $yy = $sin + $cos;
			$xx -= $x / 2;
			$yy -= $y / 2;
			$self->put_image( $xx, $yy, $i);
			$a += $pi * 2 / 3;
		}
	}
);

my ($mx, $my) = (1, 1);

$w->insert( Timer =>
	timeout => 100,
	onTick => sub {
		$angle += 0.1;
		$angle -= $pi*2 if $angle > $pi*2;
		my @p = $widget->origin;
		$p[0] += $mx * 5;
		$p[1] += $my * 5;
		$mx = 1 if $p[0] < 0 && $mx < 0;
		$my = 1 if $p[1] < 0 && $my < 0;
		$mx = -1 if $p[0] > $::application->width  - $widget->width && $mx > 0;
		$my = -1 if $p[1] > $::application->height - $widget->height && $my > 0;
		$widget->origin(@p) unless $widget->{drag};
		$widget->repaint;
	},
)->start;


run Prima;

