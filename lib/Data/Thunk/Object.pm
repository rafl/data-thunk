#!/usr/bin/perl

package Data::Thunk::Object;
use base qw(Data::Thunk::Code);

use strict;
use warnings;

use Scalar::Util qw(blessed reftype);

use namespace::clean;

use UNIVERSAL::ref;

my $dereference = sub {
    my $val = shift;
    if (reftype($val) eq 'HASH') {
        return $val;
    }
    elsif (reftype($val) eq 'ARRAY') {
        return $val->[0];
    }
    elsif (reftype($val) eq 'REF') {
        return $$val;
    }
    elsif (reftype($val) eq 'CODE') {
        return $val->();
    }
    elsif (reftype($val) eq 'GLOB') {
        return *$val{HASH};
    }
    else {
        Carp::croak("unknown reftype: $val");
    }
};

our $get_field = sub {
	my ( $obj, $field ) = @_;

	my $thunk_class = blessed($obj) or return;
	bless $obj, "Data::Thunk::NoOverload";

	my $exists = exists $obj->{$field};
	my $value = $obj->{$field};

	bless $obj, $thunk_class;

	# ugly, but it works
	return ( wantarray
		? ( $exists, $value )
		: $value );
};

sub ref {
	my ( $self, @args ) = @_;

        $self = $dereference->($self) if blessed($self);
	if ( my $class = $self->$get_field("class") ) {
		return $class;
	} else {
		return $self->SUPER::ref(@args);
	}
}


foreach my $sym (keys %UNIVERSAL::) {
	no strict 'refs';

	next if $sym eq 'ref::';
	next if defined &$sym;

	local $@;

	eval "sub $sym {
		my ( \$self, \@args ) = \@_;

                \$self = \$dereference->(\$self) if Scalar::Util::blessed(\$self);
		if ( my \$class = \$self->\$get_field('class') ) {
			return \$class->$sym(\@args);
		} else {
			return \$self->SUPER::$sym(\@args);
		}
	}; 1" || warn $@;
}

sub AUTOLOAD {
	my ( $self, @args ) = @_;
        $self = $dereference->($self) if blessed($self);
	my ( $method ) = ( our $AUTOLOAD =~ /([^:]+)$/ );

	if ( $method !~ qr/^(?: class | code )$/ ) {
		my ( $exists, $value ) = $self->$get_field($method);

		if ( $exists ) {
			if ( CORE::ref($value) && reftype($value) eq 'CODE' ) {
				return $self->$value(@args);
			} else {
				return $value;
			}
		}
	}

	unshift @_, $method;
	goto $Data::Thunk::Code::vivify_and_call;
}

1;
