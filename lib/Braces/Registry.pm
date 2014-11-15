package Braces::Registry;
use strict;
use warnings;
use Carp qw/ croak /;

# Braces::Registry->new(
#   mapping     => { ... },
#   isOpening   => sub{ ... },
#   isClosing   => sub{ ... },
#   warnings    => 0,
# )
sub new {
    my ( $class, %args ) = @_;
    $class = ref $class if ref $class;

    for (qw/ mapping isOpening isClosing /) {
        croak qq<missing "$_" argument in constructor> unless $args{$_};
    }
    croak qq<invalid "mapping" argument (not a hashref)>
      unless ref $args{mapping} eq 'HASH';
    for (qw/ isOpening isClosing /) {
        croak qq<invalid "$_" argument (not code)>
          if $args{$_} and !ref $args{$_} eq 'CODE';
    }

    bless {
        _mapping   => $args{mapping},
        _isOpening => $args{isOpening},
        _isClosing => $args{isClosing},
        _warn      => !!$args{warnings} || 0,
    } => $class;
}

sub isOpening   { $_[0]->{_isOpening}->( $_[1] ) }
sub isClosing   { $_[0]->{_isClosing}->( $_[1] ) }
sub getMirrored { $_[0]->{_mapping}{ $_[1] } }
sub isMirrored  { exists $_[0]->{_mapping}{ $_[1] } }
sub size        { scalar keys %{ $_[0]->{_mapping} } }
sub warnings    { $_[0]->{_warn} }

1;
