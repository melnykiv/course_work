#!/usr/bin/env perl

use open qw(:locale);
use strict;
#use utf8;
use warnings;
use Data::Dumper;
use Scrapper;

sub main{
	my $scrapp = Scrapper->new;

	Scrapper->start_scrapping();
}

main();
