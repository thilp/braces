package Braces;
use strict;
use warnings;
use version;
use Carp qw/ carp croak /;
use Unicode::UCD;

use parent 'Exporter';
our @EXPORT_OK = qw/ bsplit /;

use Braces::Registry;

sub try_load_module {
    my ( $name, $min_version, %import ) = @_;
    eval "require $name";
    if ( !$@ ) {
        my $version = do {
            no strict 'refs';
            version->parse( ${"${name}::VERSION"} );
        };
        croak "$name found but its version ($version) is too low "
          . "(must be at least $min_version)"
          if $version < $min_version;
        if (%import) {
            if ( $name->can('import') ) {
                $name->import( keys %import );
            }
            else { croak "can't import from $name (no import sub found)" }
        }
    }
    else {
        no strict 'refs';
        my $pkg = __PACKAGE__;
        while ( my ( $subname, $sub ) = each %import ) {
            *{"${pkg}::${subname}"} = $sub;
        }
    }
}

BEGIN {
    try_load_module( 'List::Util', 1.29,
        'pairgrep' => sub (&@) {
            my ( $code, @list ) = @_;
            my $i       = 0;
            my $max_idx = @list;
            my @grepped;
            while ( $i < $max_idx ) {
                local ( $a, $b ) = ( $list[$i], $list[ $i + 1 ] );
                push @grepped, $a, $b if &$code;
            }
            continue { $i += 2 }
            @grepped;
        }
    );
    try_load_module( 'List::MoreUtils', undef,
        'zip' => sub (++) {
            my ( $a, $b ) = @_;
            my $max_idx = @$a > @$b ? @$a : @$b;
            my @zipped;
            my $i = -1;
            while ( ++$i < $max_idx ) {
                push @zipped, $a->[$i], $b->[$i];
            }
            @zipped;
        }
    );
}

my %BMG_MAP;
INIT {
    my ( $left, $right ) = Unicode::UCD::prop_invmap('Bidi_Mirroring_Glyph');
    %BMG_MAP =
      map { chr }
      pairgrep {
        $a <= 0x10FFFF && $b ne '' && chr($a) =~ /^\p{Bidi_Mirrored}$/
      }
      zip @$left, @$right;
}

sub bsplit {
    my ( $string, $registry ) = @_;
    if ($registry) {
        croak "expected a Braces::Registry"
          if ref $registry ne 'Braces::Registry';
    } else {
        $registry = Braces::Registry->new(
            mapping   => \%BMG_MAP,
            isOpening => sub { $_[0] =~ /^\p{Bidi_Paired_Bracket_Type=Open}$/ },
            isClosing => sub { $_[0] =~ /^\p{Bidi_Paired_Bracket_Type=Close}$/ }
        );
    }
    my $result =
      _bsplit( [ CORE::split( //, $string ) ], undef, undef, $registry );
    if (@$result) {
        if ( !ref $result->[0] ) {
            pop @$result;    # remove '' at the tail
            $result = _merge_chars($result)
        } else {
            $result = $result->[0];
        }
    }
    $result
}

sub _merge_chars {
    my ($chars) = @_;
    my ( $buffer, @new_array ) = ('');
    for my $c (@$chars) {
        if ( ref $c ) {
            push @new_array, $buffer if $buffer ne '';
            push @new_array, $c;
            $buffer = '';
        } else {
            $buffer .= $c;
        }
    }
    if ( @new_array == 0 or ref $new_array[-1] ) {
        push @new_array, $buffer;
    } else {
        $new_array[$#new_array] .= $buffer;
    }
    \@new_array
}

# [ $opening_brace, @contents, $closing_brace ]
sub _bsplit {
    my ( $chars, $opening, $expected_closing, $registry ) = @_;
    my @contents;
    while ( my $c = shift @$chars ) {
        if ( $registry->isClosing($c) ) {
            if ( defined $expected_closing and $c eq $expected_closing ) {
                return [ @{_merge_chars(\@contents)}, $c ]    # normal completion
            } else {
                carp qq|unbalanced closing "$c"| if $registry->warnings;
                push @contents, $c;
            }
        } elsif ( $registry->isOpening($c) ) {

            # Recursive call
            my $rec =
              _bsplit( $chars, $c, $registry->getMirrored($c), $registry );

            my $rec_closing = pop @$rec;

            $rec = _merge_chars($rec);

            unshift @$rec, $c;    # prepend opening delimiter
            if ( $registry->isClosing($rec_closing) ) {
                push @$rec, $rec_closing;    # append closing delimitier
            } else {
                push @$rec, '';    # no $expected_closing
            }

            push @contents, $rec;

            # Abrupt stop: the recursive call did not terminate on the
            # expected closing delimiter but hit EOF. So do we.
            last if $rec_closing eq '';
        } else {
            push @contents, $c;
        }
    }

    # This only in top-level call or when EOF is reached before completion.
    if ( defined $opening ) {
        carp qq|unbalanced opening "$opening"| if $registry->warnings;
    }
    [ @contents, '' ]
}

1;
