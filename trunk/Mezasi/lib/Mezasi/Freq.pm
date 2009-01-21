package Mezasi::Freq;
use strict;
use warnings;
use utf8;
use Data::Dumper;

sub extract_terms {
    my ($class, $buf, $limit ) = @_;
    
    return $class->new($buf)->_extract_terms($limit);
}

sub new {
    my ($class, $buf ) = @_;

    return bless {
        buf => ( $buf && ref $buf eq 'ARRAY' ) ? join("\0", @$buf ) : q{ },
    }, $class;
}

sub _extract_terms {
    my ($self, $limit) = @_;

    my @terms = @{$self->extract_terms_sub($limit)};

    # before: [["hello world", 1]]
    # after:  [["dlrow olleh", 1]]
    @terms    = map { [  join('',reverse split(//, $_->[0] || ' ' ) )   , $_->[1] ] } @terms;   
    my @terms2;
    for my $idx (0..(scalar( @terms - 1) ) ) {
        my @terms_index_plus_1 = split //,$terms[$idx + 1]->[0] || ' ';
        if(  
            @{[split( //, $terms[$idx]->[0] || ' ' )]}  >= @{[split( //, $terms[$idx + 1]->[0] || ' ' )]}  
            || 
            $terms[$idx]->[0] ne  join('' , map { $terms_index_plus_1[$_] } (0..scalar( @{[split //, $terms[$idx]->[0] ]} )) )  
        ) {
            push @terms2 , $terms[$idx];
        }
        elsif( $terms[$idx]->[1] >= $terms[$idx + 1]->[1] + 2 ) {
            push @terms2 , $terms[$idx];
        }
    }        

    push @terms2, $terms[-1] if  @terms > 0 ;

    return map { join '',reverse @{[split( //, $_->[0] || ' ')]} }  @terms2 ; 

}

sub extract_terms_sub {
    my ($self, $limit, $str, $num, $width ) = @_;
    $num ||= 1;
    my $h    = $self->freq($str);

    my $flag = ( scalar( keys %$h ) <= 4 ) ? 1 : 0 ;

    my @result;
    if( $limit > 0 ) {
        if( $str &&  defined $h->{$str} ) {
            delete $h->{$str};
        }
        for my $key ( grep { $h->{$_} > 2 } sort { $h->{$a} <=> $h->{$b} }  keys %$h ) {
            push @result, $self->extract_terms_sub( $limit - 1, $key , $h->{$key}, $flag );
        }
    }

    if( scalar( @result ) == 0 && $width ) {
        return [ ( lc $str, $num ) ];
    }

    return \@result;
}

sub freq {
    my ($self, $str ) = @_;
    my $freq = {};
    
    if( scalar(  @{[split(//,$str || '')]}  ) == 0 ) {
        while( $self->{buf} =~ /([!-~])[!-~]*|([ァ-ヴ])[ァ-ヴー]*|([^ー\0])/gi ) {
            $freq->{ $1 || $2 || $3 } += 1;
        }
    }
    else {
        while( $self->{buf} =~ /($str)[^\0]?/gio ) {
            $freq->{$1} += 1;
        }
    }
    return $freq;
}

1;
