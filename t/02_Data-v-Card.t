#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use Test::More 'no_plan';
#use Test::More tests => 10;
use Test::Differences;
use Test::Exception;
use Test::Deep;

binmode(Test::More->builder->$_ => q(encoding(:UTF-8))) for qw(output failure_output todo_output);

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
	use_ok ( 'Data::v' ) or exit;
}

exit main();

sub main {
	basic();
	photo();
	return 0;
}

sub basic {
	my $aldo_vcf = IO::Any->slurp([ $Bin, 'vcf', 'aldo.vcf' ]);
	my $vdata = Data::v->new->decode(\$aldo_vcf);
	
	cmp_deeply([$vdata->keys], ['VCARD'], 'one VCARD record');
	my $vcard = $vdata->get_value('VCARD');
	isa_ok($vcard, 'Data::v::Card');
	cmp_ok($vcard->get_value('VERSION'), 'eq', '2.1', 'VERSION 2.1');

	is($vdata->line_ending, "\r\n", 'line_ending()');
	is($vcard->line_ending, "\r\n", 'line_ending()');
	
	my $aldo_vcf_enc = $vdata->encode(undef, [ '/tmp/aldo.vcf' ]);
	is($aldo_vcf, $aldo_vcf_enc, 'encode back and compare with original');
	
	is($vcard->get_value('ADR')->country, 'Österreich', 'adr->country() in Windows-1252');

	my $enc_vcf = IO::Any->slurp([ $Bin, 'vcf', 'enc.vcf' ]);
	my $enc_vdata = Data::v->new->decode(\$enc_vcf);
	my $enc_vcard = $enc_vdata->get_value('VCARD');
	foreach my $line (@{$enc_vcard->_lines}) {
		$line->line_changed;
	}
	
	is($enc_vdata->encode(), $enc_vcf, 'encode back and compare with original (mixed encoding)');
	cmp_ok($enc_vcard->get_value('N'), 'eq', 'aäčšťľžř;aacsztl', 'encoded N (iso-8859-2)');
	cmp_ok($enc_vcard->get_value('FN'), 'eq', 'aacsztl aäčšťľžř', 'encoded FN (windows-1250)');
	cmp_ok($enc_vcard->get_value('PHOTO'), 'eq', 'http://www.gravatar.com/avatar/b6e8656226999389e5098d10e00226fe?just-test=ůčšžťľä', 'encoded FN (iso-8859-2)');
	
	TODO: {
		local $TODO = 'uri-s should be decoded as URI objects';
		isa_ok($enc_vcard->get_value('PHOTO'), 'URI', 'photo uri as URI object');
	}
}

sub photo {
	my $aldo_vcf = IO::Any->slurp([ $Bin, 'vcf', 'aldo.vcf' ]);
	my $aldo_img = IO::Any->slurp([ $Bin, 'vcf', 'aldo.jpg' ]);

	my $vdata = Data::v->new->decode(\$aldo_vcf);
	my $vcard = $vdata->get_value('VCARD');
	
	my $photo_bin = $vcard->get_value('photo');
	IO::Any->spew([ $Bin, 'vcf', 'aldo.jpg-extracted' ], $photo_bin);
	ok($photo_bin eq $aldo_img, 'extract photo');
}
