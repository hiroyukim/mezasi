package Mezasi::StringUtil;
use strict;
use warnings;
use utf8;
use Exporter;
use base 'Exporter';

our($VERSION, @ISA, @EXPORT, @EXPORT_OK);
@EXPORT_OK = qw(list_s reverse_s byte_s);  
$VERSION = '0.001';

sub list_s ($)        { split('', shift )  }

sub reverse_s($) { 
    my $str = shift;

    return wantarray ? reverse list_s($str) : join('', reverse list_s($str) ) ; 
}

sub byte_s($)    { map ord, list_s( shift )  } 

1;
