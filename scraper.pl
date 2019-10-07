#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8 encode_utf8);
use English;
use HTML::TreeBuilder;
use LWP::UserAgent;
use URI;

# Don't buffer.
$OUTPUT_AUTOFLUSH = 1;

# URI of service.
my $base_uri = URI->new('http://www.brno.cz/sprava-mesta/volene-organy-mesta/'.
	'zastupitelstvo-mesta-brna/');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite',
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

# Get base root.
print 'Page: '.$base_uri->as_string."\n";
my $root = get_root($base_uri);

# Look for items.
my $telo = $root->find_by_attribute('id', 'telo');
my @div = $telo->find_by_tag_name('div');
my @cells = $div[3]->find_by_tag_name('td');

foreach my $content ($cells[0], $cells[2]) {
	my @names = split( qr{<br />}, $content->as_HTML);

	foreach my $name (@names) {
		my ($jmeno, $strana) = parse_name($name);
		$dt->insert({
			'Jmeno' => $jmeno,
			'Strana' => $strana,
		});
	}
}

# Get root of HTML::TreeBuilder object.
sub get_root {
	my $uri = shift;
	my $get = $ua->get($uri->as_string);
	my $data;
	if ($get->is_success) {
		$data = $get->content;
	} else {
		die "Cannot GET '".$uri->as_string." page.";
	}
	my $tree = HTML::TreeBuilder->new;
	$tree->parse(decode_utf8($data));
	return $tree->elementify;
}

# Parse name.
sub parse_name {
	my $name_string = shift;
	$name_string =~ s/^\s*\d+\..*?\</\</ms;
	$name_string =~ s/\x{00a0}/ /ms;

	my ($name, $party) = $name_string =~ m/^.*?<a href.*?>(.*?)<\/a>.*?\((.*)\)/ms;
	if (defined $party && $party eq decode_utf8('ŽTB*')) {
		$party = decode_utf8('Žít Brno s podporou Pirátů');
	}
	return ($name, $party);
}
