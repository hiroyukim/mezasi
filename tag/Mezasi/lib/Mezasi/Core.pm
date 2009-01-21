package Mezasi::Core;
use strict;
use warnings;
use utf8;

use List::Util qw/sum shuffle/;
use List::MoreUtils qw/uniq/;
use Mezasi::Dictionary;
use Mezasi::Util;

sub new {
    my ($class, $dirname ) = @_;

    bless { 
        dic => Mezasi::Dictionary->load( $dirname || '') 
    } , $class;
}

sub split_into_keywords {
    my ( $self, $string ) = @_;
    
    my %result = {};
    for my $term ( $self->split_into_terms( $string) ) {
        $result{$term} = length( $term );
    }
}

sub split_into_terms {
    my ( $self, $str , $num ) = @_ ;
    
    return $self->{trie}->split_into_terms($str, $num);
}

sub weight {
    my ( $self, $word ) = @_;

    if( defined $self->rel->{$word} || ( $self->rel->{$word}->{sum} || 0 ) == 0 ) {
        return 0;
    }
    else {
        my $num = $self->rel->{$word}->{num};
        my $sum = $self->rel->{$word}->{sum};

        return $num / ( $sum * ( $sum + 100 ) );
    }
}

sub talk {
    my ( $self, $string, $weight ) = @_;

    my $keywords;
    if( $string ) {
        $keywords = $self->{dic}->split_into_keywords( $string );    
    }
    else {
        my @text        = $self->{dic}->{text};
        my @latest_text = ( scalar( @text ) < 10 ) ? @text : map { $text[$_] } (-10..-1) ; 

        $keywords = {};

        for my $str ( @latest_text ) {
            for my $key ( keys %$keywords ) { $keywords->{$key} *= 0.5 ; }
            for my $key ( $self->dic->split_into_keywords( $string ) ) { $keywords->{$key} += $keywords->{$key}; }
        }
    }

    for my $key (keys  %{$weight} ) {
        if( defined $keywords->{$key} ) {
            if( $weight->{$key} == 0 ) {
                delete $keywords->{$key};
            }
            else {
                $keywords->{$key} *= $weight->{$key};
            }
        }
    }

    my $msg = $self->message_markov( $keywords );

}

sub message_markov {
    my ( $self, $keywords ) = @_;

    my @lines;
    if( scalar( keys %{$keywords} ) > 0 ) {
        if( scalar( keys %{$keywords} ) > 10 ) {
            my $count;
            for my $key ( sort { $a <=> $b } keys %{$keywords} ) {
                if( $count > 10 ) { delete $keywords->{$key} }
                $count++; 
            }

        }
        my $sum = sum values %{$keywords}; 

        if( $sum > 0 ) {
            for my $key ( keys %{$keywords} ) {
                $keywords->{$key} = $keywords->{$key} / $sum;
            }
        }

        for my $key ( keys %{$keywords} ) {
            # occur : 'hoge' => { ( 1 ,2 , 3) ]
            my @occurs = shuffle @{$self->{dic}->lines($key)} ;
            for my $idx (0..10) {
                push @lines , $occurs[$idx] if $occurs[$idx];
            }
        }
    }

    for(0..10) {
        push @lines ,  int rand( scalar @{$self->{dic}->{text}}  );
    }

    @lines = uniq @lines;

    my @source = uniq shuffle map { @{$_} } map { my @result; for my $line ($_..5) { push @result, $self->{dic}->{text}->[$line] if $self->{dic}->{text}->[$line] ; } \@result; } uniq @lines; 
    my $msg = Mezasi::Util->markov( \@source , $keywords, $self->{dic}->{trie} );        
    $msg    = Mezasi::Util->message_normalize($msg);

    return $msg;
}

sub memorize {
    my ( $self , $lines ) = @_;

    $self->{dic}->store_text($lines);
    if( $self->{dic}->learn_from_text ) {
        $self->{dic}->save_dictionary;    
    }
}

1;
