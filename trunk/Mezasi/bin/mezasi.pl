use strict;
use warnings;
use utf8;
use encoding 'utf8';

use boolean qw/:all/;
use Getopt::Long;
use Pod::Usage;
use IO::Prompt;
use Mezasi::Core;

Getopt::Long::GetOptions(
    '-i'         => \my $readline,
    '-m'         => \my $memory,
    '--init'     => \my $init,
    '-dirname=s' => \my $dirname,
    '-string=s'  => \my $string,
    '--man'      => \my $man, 
) or pod2usage(2);
Getopt::Long::Configure("bundling");
pod2usage(-verbose => 2) if $man;
pod2usage(2) if !$dirname; 

if( $init ) {
    my $dic = Mezasi::Core->init_dictionary($dirname);
    $dic->save_dictionary;
}
elsif( $readline ) {
    my $sixamo =  Mezasi::Core->new($dirname);
    print "簡易対話モード [exit,quit,空行で終了]\n";

    while(my $prompt = prompt ">" ) {
        my $str = $prompt->{value};
        last if( $str =~ /^(exit|quit)?$/ ); 

        if( $memory ) {
            $sixamo->memorize($str);
        }

        my $res = $sixamo->talk($str) || '';

        print $res ."\n";
    }

}
else {
    my $sixamo =  Mezasi::Core->new($dirname);
    my $res = $sixamo->talk($string);
    print $res."\n";
}


1;
__END__

=head1 SYNOPSIS

    mezasi.pl -i -m dirname

    Options:
        -i        ターミナル上で話す
        -m        会話の記録をおこなうか
        -dirname  データ保存のディレクトリ名
        --init    バージョンUP用
        --man     ヘルプ表示

=head1 DESCRIPTION

    めざし起動用スクリプト

=head1 AUTHORS

    Hiroyuki Yamanaka <hiroyukimm@gmail.com>

