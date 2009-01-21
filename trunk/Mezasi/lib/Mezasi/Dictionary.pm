package Mezasi::Dictionary;
use strict;
use warnings;
use utf8;

use Switch;
use IO::File;
use File::Copy;
use List::MoreUtils qw/uniq/;
use Mezasi::Trie;
use Mezasi::Freq;
use Data::Dumper;

our $TEXT_FILENAME = 'sixamo.txt';
our $DIC_FILENAME  = 'sixamo.dic';
our $WindowSize    = 500;

sub new {
    my ( $class, $dirname ) = @_;

    my $self = bless  {
        occur         => \my %occur,
        rel           => \my %rel,
        trie          => Mezasi::Trie->new,
        dirname       => $dirname || undef, 
        text_filename => "@{[$dirname]}/@{[$TEXT_FILENAME]}",
        dic_filename  => "@{[$dirname]}/@{[$DIC_FILENAME]}",
        text          => \my @text,
        line_num      => 0,
    } , $class;

    return $self;
}

sub load {
    my ( $self, $dirname ) = @_;

    my $dic = Mezasi::Dictionary->new($dirname);
    $dic->load_text;
    $dic->load_dictionary;

    return $dic;
}

sub load_text {
    my $self = shift;

    return unless( -e $self->{text_filename} );

    my $io = IO::File->new( $self->{text_filename} , "<:utf8" );   

    while( my $line = <$io> ) {
        chomp($line);

        push @{$self->{text}}, $line ;
    }
}

sub load_dictionary {
    my $self = shift;

    return unless( -e $self->{dic_filename} );

    my @lines = IO::File->new($self->{dic_filename}, "<:utf8")->getlines;

    my $line_num = shift @lines;
    ($self->{line_num},) = ( $line_num =~ /line_num:\s*(.*)\s*$/i ); 

    for my $line (@lines) {
        chomp $line;

        my ($word,$num,$sum,$occur) = split(/\t/, $line );

        if( $occur ) {
            $self->{occur}->{$word} = [ map { int $_ } split( /,/, $occur ) ];
            $self->add_term($word);
            $self->{rel}->{$word} = {};
            $self->{rel}->{$word}->{num} = int $num;
            $self->{rel}->{$word}->{num} = int $sum;
        }
    }
}

sub save_text {
    my $self = shift;

    my $tmp_file_name = "@{[$self->dirname]}/sixamo.tmp.@{[$$]}-@{[rand(100)]}";

    my $fp = IO::File->new( $tmp_file_name, ">>:utf8" );

    for my $line (@{$self->text}) {
        print $fp $line;
    }

    File::Copy::move( $tmp_file_name , $self->{dic_filename} );
}

sub save_dictionary {
    my $self = shift;

    my $tmp_file_name = "@{[$self->{dirname}]}/sixamo.tmp.@{[$$]}-@{[rand(100)]}";

    my $fp = IO::File->new( $tmp_file_name,">:utf8" );

    print $fp $self->to_s;

    File::Copy::move( $tmp_file_name , $self->{dic_filename} );

}

sub to_s {
    my $self = shift;

    my $result = '';
    $result .= "line_num: @{[$self->{line_num}]}\n";
    $result .= "\n";

    %{$self->{occur}} = map { ( $_ =>  $self->{occur}->{$_} ) } grep { $self->{occur}->{$_} && ( not ( scalar( @{$self->{occur}->{$_}} ) == 0 ) ) } keys %{$self->{occur}};
   
    while( my ( $key , $value ) = each %{$self->{occur}} ) {
        $self->{oocur}->{$key} = [ map { $value->[$_] } (-100..-1) ] if( $value && scalar( @{$value} ) > 100 ); 
    }
   
    my @tmp;
    for my $key ( sort { $a cmp $b } keys %{$self->{occur}} ) {
        push @tmp , [ - scalar( @{$self->{occur}->{$key}} ) , $self->{rel}->{$key}->{num}, scalar( @{[split(//,$key)]} ) , $key ]; 
    }

    for my $key ( @tmp ) {
        $result .= sprintf("%s\t\%s\t\%s\t%s\n",
            $key,
            $self->{ocuur}->{$key}->{num},
            $self->{ocuur}->{$key}->{sum},
            join(',', @{$self->{occur}->{$key}} )
        );      
    }

    return $result;
}

sub learn_from_text {
    my ($self, $progress ) = @_;

    my $modified = undef;

    my $read_size = 0;
    my @buf_prev;
    my $end_flag  = undef;
    my $idx       = $self->{line_num};

    while(1) {
        my @buf;

        if( $progress ) {
            my $idx2 = $read_size / $WindowSize * $WindowSize ;

            if( $idx2 % 100000 == 0 ) {
                warn sprintf("\n%5dk", $idx2/1000 ) ;
            }
            elsif ( $idx2 % 20000 == 0 ) {
                warn "*";
            }
            elsif ( $idx2 % 2000 == 0 ) {
                warn ".";
            }
        }

        my $tmp = $read_size;
        while( $tmp/$WindowSize == $read_size/$WindowSize ) {
            if( $idx >= scalar( @{$self->{text}} ) ) {
                $end_flag = 1;
                last;
            }

            push @buf , $self->{text}->[$idx] ;
            $tmp += scalar( @{$self->{text}} ) ;
            $idx++;
        }

        $read_size = $tmp;

        last if $end_flag ;

        if( scalar( @buf_prev ) > 0 ) {
            $self->learn(  [ (@buf_prev , @buf) ] , $self->{line_num} );
            $modified = 1;

            $self->{line_num} += scalar( @buf_prev );
        }

        @buf_prev = @buf;
    }

    warn "\n" if $progress;

    return $modified;
}

sub store_text {
    my ($self, @lines) = @_;

    my @ary;
    for my $line (@lines) {
        $line =~ s/\s+/ /;
        push @ary, $line; 
    }

    push @{$self->{text}} , @ary;

    my $fp = IO::File->new( $self->{text_filename} , ">>:utf8");
    for my $line (@ary) {
        chomp $line;

        print $fp $line."\n";
    }

    $fp->close;

    return;
}

sub learn {
    my ($self, $lines, $idx ) = @_;

    my @new_terms = Mezasi::Freq->extract_terms( $lines, 30 );

    for my $term ( @new_terms ) {
        $self->add_term($term);
    }

    if( $idx ) {
        my @words_all;

        my $count=0;
        for my $line ( @{$lines} ) {
            my $num = $idx + 1;
            my @words = @{$self->split_into_terms($line)};
            @words_all = (@words_all,@words);

            for my $term (@words) {
                if( not  $self->{occur}->{$term}  || $num > ( $self->{occur}->{$term}->[-1] || 0 ) ) {
                    push @{$self->{occur}->{$term}} , $num;
                }
            }
        }

        $self->weight_update(@words_all);

        for my $term (@{$self->{terms}}) {
            my $occur = $self->{occur}->{$term};
            my $size  = scalar( keys %{$self->{occur}} );

            if( $size < 4 && $size > 0 && $occur->{num} * $size * 150 < $idx ) {
                $self->del_term($term);
            }
        }
    }
}

sub split_into_keywords {
    my ($self, $str ) = @_;

    my @terms = @{$self->split_into_terms($str)};
    my $result = {};
    for my $word ( @terms ) {
        $result->{$word} += $self->weight($word);    
    }

    return $result; 
}

sub split_into_terms {
    my ($self, $str, $num ) = @_;

    return $self->{trie}->split_into_terms($str,$num);
}

sub weight_update {
    my ($self, @words) = @_;
    my $width = 20;

    for my $term (@words) {
        $self->{rel}->{$term} = {} unless defined $self->{rel}->{$term};
    }

    my $size = scalar @words;
    for my $idx1 (0..($size-$width)) {
        my $word1 = $words[$idx1];
        
        for my $idx2 ( ($idx1+1)..($idx1+$width) ) {
            $self->{rel}->{$word1}->{num} += 1 if $word1 eq $words[$idx2];
            $self->{rel}->{$word1}->{sum} += 1;
        }
    }

    for my $idx1 ( 0..($width + 1 ) ) {
        my $word1 = $words[$idx1];

        if( $word1 ) {
            for my $idx2 ( reverse ( 1..($idx1 -1)) ) {
                $self->{rel}->{$word1}->{num} += 1 if $word1 eq $words[-$idx2];
                $self->{rel}->{$word1}->{sum} += 1;
            }
        }
    }

    return;
}

sub weight {
    my ($self, $word ) = @_;

    if( ( not $self->{rel}->{$word} ) ||  ( not $self->{rel}->{$word}->{sum} ) || ( $self->{rel}->{$word}->{sum} || 0 ) == 0  ) {
        return 0;
    }
    else {
        my $num = $self->{rel}->{$word}->{num} || 0;
        my $sum = $self->{rel}->{$word}->{sum} || 0;

        return $num/($sum*($sum+100));
    }
}

sub lines {
    my ($self, $word ) = @_;

    return   $self->{occur}->{$word} || [];
}

sub terms {
    my  $self = shift;

    return ( keys %{$self->{occur}} );
}

sub add_term {
    my ( $self, $str ) = @_;

    $self->{occur}->{$str} = qw() unless $self->{occur}->{$str};

    $self->{trie}->add($str);
    $self->{rel}->{$str}  = {} unless $self->{rel}->{$str}; 

    return;
}

sub del_term {
    my ($self, $str ) = @_;

    my @occur = $self->{occur}->{$str};

    delete $self->{occur}->{$str};
    delete $self->{trie}->{$str};
    delete $self->{rel}->{$str};

    my @tmp = $self->split_into_terms($str);

    for my $word (@tmp) {
        $self->{occur}->{$word} = [ sort { $a <=> $b } uniq ( @{$self->{occur}->{$word}} , @occur ) ];
        $self->weight_update(@tmp) if( scalar( @tmp ) > 0 ); 
    }

    return;
}

1;
