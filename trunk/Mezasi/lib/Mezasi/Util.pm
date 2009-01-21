package Mezasi::Util;
use strict;
use warnings;
use utf8;
use base qw/Class::Accessor::Fast/;

use Data::Dumper;
use List::Util qw/sum/;
use List::MoreUtils qw/uniq/;
use boolean qw/:all/;
use JSON::Syck;

use Mezasi::Trie;

our $MarkovKeySize = 2;

sub markov {
    my ( $self, $src, $keywords, $trie ) = @_;
    my $mar    = $self->markov_generate( $src , $trie );
    my $result = $self->markov_select($mar, $keywords );

    return $result;
}

sub markov_generate {
    my ( $self, $src, $trie ) = @_;

    return '' if( scalar( @{$src} ) == 0 );
    my @ary = @{$trie->split_into_terms( join( "\n", @{$src} )."\n", 'true')}; 
    my $size = scalar @ary;
    push @ary, grep {$_} map { $ary[$_] } (0..$MarkovKeySize);
    my %table; 
    for my $idx ( 0..($size - 1) ) { 
        my $key = JSON::Syck::Dump([ grep {$_} map {  $ary[$_]  } ($idx..($idx+$MarkovKeySize - 1)) ]);
        $table{$key} = [] unless $table{$key};
        push @{$table{$key}},$ary[$idx + $MarkovKeySize ] ;
    }
    my %uniq;
    my %backup;

    while( my ($key, $value ) = each %table ) {
        if( scalar( @{$value} ) == 1 ) {
            $uniq{$key} = $value->[0];
        }
        else {
            $backup{$key} = [ @{$table{$key}} ];
        }
    }
    my $key    = JSON::Syck::Dump([ map { $ary[$_] } (0..($MarkovKeySize - 1 )) ]);
    my $result = join('',@{JSON::Syck::Load($key)}); 
    for my $count ( 0..10000 ) {
        my $str;
        if( defined $uniq{$key} ) {
            $str = $uniq{$key};    
        }
        else {
            if( $table{$key} && scalar( @{$table{$key}} ) == 0 ) {
                $table{$key} =  ( ref $backup{$key} ) ?  [@{$backup{$key}}] : [];
            }
            my $idx = rand( ( ref $table{$key} ) ? scalar @{$table{$key}} : 0 );
            my $str = $table{$key}->[$idx];

            $table{$key}->[$idx] = undef;
            $table{$key} = [ grep { $_ } @{$table{$key}} ]; 
        }

        $result .= $str || '';
        $key = JSON::Syck::Load($key);
        push @{$key} , $str ;
        $key     = JSON::Syck::Dump([ map { $key->[$_] } (1..$MarkovKeySize ) ]) ; 
    }

    return $result;
}

sub markov_split {
    my ($self, $str ) = @_;

    my @result;
    while( $str =~ /^(.{25,}?)([。、．，]+|[?!.,]+[\s　])[ 　]*/ ) {
        my $m  = $1;
        my $m2 = $2;
        my $post_match = $';
        if( $m2 ) {
            $m2 =~ s/、/。/m; 
            $m2 =~ s/，/．/m; 
        }
        $m .= $m2;
        push @result, $m;
        $str = $post_match; 
    }

    if( scalar( @{[split(//,$str)]} ) > 0  ) {
        push @result, $str;
    }
    return \@result;
}

sub markov_select {
    my ($self, $result, $keywords ) = @_;

warn Dumper $keywords;
    my @tmp = split(/\n/, $result) or qw();
    my @test = map { @{$self->markov_split($_)} } @tmp; 
warn Dumper \@test;    
    my @result_ary = uniq map { @{$self->markov_split($_)} } @tmp; 
    @result_ary = grep { $_ || $_ !~ /\0/ } @result_ary;
    my %result_hash;

    my $trie = Mezasi::Trie->new([ keys %{$keywords}]);
warn Dumper $trie;
    for my $str ( @result_ary ) {
        my @terms          = uniq @{$trie->split_into_terms($str)};
        $result_hash{$str} = ( sum map { $keywords->{$_} } @terms ) || 0; 
    }
warn Dumper \%result_hash;
    $result = $self->roulette_select(\%result_hash);
warn 'result';
warn Dumper $result;
    return $result || '';
}

sub roulette_select {
    my ($self, $h ) = @_;

    return if( scalar( keys %$h ) == 0 );

    my $sum = sum values %$h; 

    if( $sum == 0 ) {
        return $self->random_select( [ keys %$h ] );
    }

    my $r = int( rand * $sum );
    while( my ($key , $value ) = each %$h ) {
        $r -= $value;
        if( $r <= 0 ) {
            return $key ;
        }     
    }

    return $self->random_select( [ keys %$h ] );
}

sub random_select {
    my ($self, $ary ) = @_;

    return $ary->[rand(scalar(@{$ary}))];
}

sub message_normalize {
    my ($self, $str ) = @_;

    my %pare_h;
    for my $paren ( qw{「」 『』 （） () } ) {
        for my $ch ( split('', $paren ) ) {
            $pare_h{$ch} = [ split('',$paren) ];
        }
    }

    $str =~ s/「」//g;
    $str =~ s/（）//g;
    $str =~ s/『』//g;
    $str =~ s/\(\)//g;

    return $str;
}

1;
