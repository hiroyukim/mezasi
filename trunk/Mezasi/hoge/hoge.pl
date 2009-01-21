use strict;
use warnings;
use Perl6::Say;

my $str = 'tester';

for my $byte ( map ord, split('', $str) ) {
    say $byte;    
}



