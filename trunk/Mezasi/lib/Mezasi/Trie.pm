package Mezasi::Trie;
use strict;
use warnings;
use utf8;

use boolean qw/:all/;

sub new {
    my ($class , $ary ) = @_;

    my $root = {};

    my $self = bless { root => $root }, $class;  

    if( $ary ) {
        for my $eml (@{$ary}) {
            $self->add($eml);
        }
    }

    return $self;
}

sub add {
    my ($self, $str ) = @_;

    my $node = $self->{root};

    for my $byte (map ord, split //, $str) { 
        $node->{$byte} = {} unless $node->{$byte} ;
        $node = $node->{$byte};
    }

    $node->{terminate} = true;

    return $self->{root};
}

sub longest_prefix_subword {
    my ($self, $str ) = @_;

    my $node = $self->{root};

    my $result;
    my $idx = 0 ;

    my @strs = split('',$str );
    for my $byte ( map ord , split('',$str ) ) {
        $result = join( '', map { $strs[$_] } (0..$idx) ) if $node->{terminate} ; 
        return $result unless $node->{$byte};
        $node = $node->{$byte};
        $idx++;
    }

    $result = $str if $node->{terminate};

    return $result;
}

sub split_into_terms {
    my $self  = shift;
    my $str   = shift;
    my $num   = shift || '';

    return [] unless $str;
    
    my @result;
    while( $str and  ( $num =~ /^\D*?$/ || ( scalar( @result)  < $num ) )) {

        my $prefix = $self->longest_prefix_subword($str);

        if( $prefix ) {
            push @result , $prefix;
            my @strs = split(//,$str);
            $str = join('', map { $strs[$_] } ( scalar( @{[split(//,$prefix)]} ) .. -1) ); 
        }
        else {
            my ($char,@str_tmp ) = split(//, $str);
            push @result , $char if $num;
            $str = join('',@str_tmp );
        }
    }

    return \@result;
}

sub member {
    my ($self, $str ) = @_;
    
    my $node = $self->{root};

    for my $byte (split(//, $str)) {
        return unless defined $node->{$byte}; 
        $node = $node->{$byte};
    }

    return ( defined $node->{terminate} ) ? 1 : 0 ; 
}

sub members {
    my $self = shift;

    $self->member_sub($self->{root});
}

sub members_sub {
    my ($self , $node , $str ) = @_;

    my @result;
    while( my ( $key , $value ) = each %$node ) {
        if( $key eq 'terminate' ) {
            push @result, $str; 
        }
        else {
            map { push @result , $_ } @{ $self->members_sub( $str, $str.$key ) };
        }
    }

    return \@result;
}

sub delete {
    my ($self, $str ) = @_;

    my $node = $self->{root};
    my @ary;

    my @strings = map ord , split('',$str );
    for my $byte ( @strings ) {
        return unless( $node->{$byte} );
        push @ary , [ $node, $byte ];
        $node = $node->{$byte};
    }

    return unless $node->{terminate};
    push @ary , [$node, 'terminate'];

    for my $data ( reverse @ary ) {
        my ( $node , $byte ) = @{$data}; 
        delete $node->{$byte};
        last unless $node ;
    }

    return 1;
}

1;
