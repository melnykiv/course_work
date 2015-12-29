#!/usr/bin/env perl

package Scrapper;

use open qw(:locale);
use strict;
#use utf8;
use warnings;
use LWP::UserAgent;
use WWW::Mechanize;
use File::Path qw(make_path);
use Config::Simple;
use Data::Dumper;
use Win32::IEAutomation;
use Encode qw/encode decode/; 
use utf8; 

my $encoding = $^O eq 'MSWin32' ? 'cp850' : 'utf8';
binmode(STDOUT, ":encoding($encoding)" );

my $ua; 
my %config;
my $search_done = 0;

sub new{
 	my $class = shift;

 	$ua = LWP::UserAgent->new;
		$ua->timeout(10);
		$ua->env_proxy;

	%config = $class->get_config();
}

sub start_scrapping{
	my ($this) = shift;

	print "Scraping data from pastebin.com\n";
	while (true){
		$this->scrap_pastebin();
		sleep(1000);
	}
	my $storage = $config{Pastebin_Storage_Path};

	$SIG{TERM} = sub { die "Scraping stoped.\nPlease check $storage for data." };
}

sub scrap_pastebin{
	my ($this) = shift;

	my $pastebin_storage_path = $config{Pastebin_Storage_Path};
	make_path($pastebin_storage_path);

	

	my @new_pastes;

	if ($search_done != 1){
		push @new_pastes, $this->get_searched_pastes();
		#print "ololo";
		$search_done = 1;
	}

	foreach my $paste (@new_pastes){ 
		my $filename = $pastebin_storage_path . $paste . '.html';
		next if (-f $filename); 

		my $content = $this->get_paste_content($paste);
		if ($content){
			my $results = $this->filter_content($content);
			if (defined $results){
				my $header_string = '';
				
				open my $fh, '>>', $filename or die "$!";

				print "new content loading: pastebin.com$paste\n";
				print $fh 'http://pastebin.com' . $paste;

				my $mech = WWW::Mechanize->new(stack_depth => 0);
				$mech->get('http://pastebin.com' . $paste);

				print $fh $mech->text();

			}
		}
	}
}

sub get_recent_pastes{
	my ($this) = shift;

	my @pastes;

	my $mech = WWW::Mechanize->new(stack_depth => 0);
	$mech->get('http://pastebin.com/archive');
	my @links = $mech->find_all_links(url_regex => qr/\/([A-Z])\w{7,}/);
	foreach my $link (@links) {
		push @pastes, $link->URI();
	}

	return @pastes;
}

sub get_paste_content{
	my ($this, $paste_url) = @_;

	my $mech = WWW::Mechanize->new(stack_depth => 0);
	$mech->get('http://pastebin.com' . $paste_url);

	return $mech->text() if (defined $mech);
	return undef;
}

sub filter_content{
	my ($this, $content) = @_;

	my $counter = 0;
	my @results = {};

	my @keywords = $this->get_keywords();

	foreach my $keyword (@keywords){
		my $search_res = "Search results for: $keyword";

		my @keyword_array = split(' ', $keyword);
		my $word_count = scalar @keyword_array;
		my $local_counter = 0;
		foreach my $key (@keyword_array){
			if ($content =~ qr/$key/){
				$counter++;
				$local_counter++; next;
			}
		}
		if ($local_counter >= $word_count)
			{
				push @results, $keyword;
			}

	}
	if ($counter != 0){
		return @results;
	}
	return undef;
}

sub get_searched_pastes{
	my ($this) = shift;

	my @pastes;

	my $mech = WWW::Mechanize->new(stack_depth => 0);
	my $ie = Win32::IEAutomation->new( visible => 0, maximize => 1);

	my $url_query = 'http://pastebin.com/search?q=';
	my $query_string = '';

	my @keywords = $this->get_keywords();

	foreach my $keyword (@keywords){
		my @splitted_keyword = split(' ', $keyword);
		$query_string = join('+', @splitted_keyword);
		my $url_query_build = $url_query . $query_string;


		$mech->get($url_query_build);
		$ie->gotoURL($url_query_build);

		my @links; 

		my @urls = map { $_->linkUrl() } $ie->getAllLinks();

		foreach my $link (@urls) {
			if ($link =~ qr/\/([A-Z0-9])\w{7,}/i){
				$link = substr($link, 19);
				push @links, $link;
			}
		}

		push @pastes, @links;
	}

	return @pastes;
}

sub get_keywords{
	my ($this) = shift;

	my @data;

	my $keywords_file = 'c:/workspace/course_work/conf/keywords.ini' ;
	open INFILE, "$keywords_file" ; 
	@data = <INFILE> ; 
	close INFILE ;

	return @data;
}

sub get_config{
	my ($this) = shift;

	my $config_file = 'c:/workspace/course_work/conf/app.ini';

	open FILE1, $config_file or die $!;
	my %hash;
	while (my $line=<FILE1>) {
	   	chomp($line);
	   	(my $param1, my $param2) = split /#/, $line;
	   	$hash{$param1} = $param2;
	}

	return %hash;
}

1;