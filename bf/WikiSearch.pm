package buzzfeed2::WikiSearch;

use strict;
use warnings;

use XML::Simple;
use Error qw(:try);
use buzzfeed2::StringUtil;
use buzzfeed2::memcache::Cache;
use buzzfeed2::Scraper;

use constant LIMIT         => 10;
use constant CACHE_TIMEOUT => 3600;

sub search {
	my ( $self, $args ) = @_;

	return [] if !$args->{search};

	my $cache_key = 'wiki_searc_' . lc( $args->{search} );
	$cache_key =~ s/\s+/_/g;
	my $cache = buzzfeed2::memcache::Cache->instance()->getConnection();
	my $data  = $cache->get($cache_key);
	return $data if defined $data;

	$args->{source} = 'wiki';
	$data = buzzfeed2::Scraper->get_from_db($args);
	$cache->set( $cache_key, $data, CACHE_TIMEOUT );
	return $data;
}

sub search_web {
	my ( $self, $args ) = @_;

	my $search_url   = 'http://en.wikipedia.org/w/api.php';
	my $search_param = {
		search => $args->{search},
		action => 'opensearch',
		format => 'xml',
		limit  => LIMIT,
	};
	my $response = buzzfeed2::Scraper->request( $search_url, $search_param );
	return if $response->is_error;

	my $xs       = new XML::Simple;
	my $xml_data = $xs->XMLin( $response->content );

	if ( !$xml_data || !$xml_data->{Section}{Item} || ref( $xml_data->{Section}{Item} ) ne 'ARRAY' ) {
		return [];
	}
	my @data     = map {
		url     => $_->{Url}{content},
		  title => $_->{Text}{content},
		  text  => buzzfeed2::StringUtil->clean( $_->{Description}{content} )
	}, @{ $xml_data->{Section}{Item} };
	return \@data;
}

sub search_page {
	my ( $self, $args ) = @_;

	return if !$args->{page};

	my $search_url   = 'http://en.wikipedia.org/w/api.php';
	my $search_param = {
		page   => $args->{page},
		action => 'parse',
		prop   => 'text',
		format => 'xml',
	};
	my $response = buzzfeed2::Scraper->request( $search_url, $search_param );
	return if $response->is_error;

	my $xs       = new XML::Simple;
	my $xml_data = $xs->XMLin( $response->content );
	my $html     = $xml_data->{parse}{text}{content};
	my $count;
	my $res = '';

	while ( $html =~ /<p>(.+)<\/p>/g ) {
		$count++;
		last if $count > 2;
		my $p = buzzfeed2::StringUtil->clean($1);
		$res .= "<p>$p</p>\n";
	}
	return $res;
}

sub get_page {
	my ( $self, $args ) = @_;

	return if !$args->{page};

	my $cache_key = 'wiki_page_' . lc( $args->{page} );
	$cache_key =~ s/\s+/_/g;
	my $cache = buzzfeed2::memcache::Cache->instance()->getConnection();
	my $res   = $cache->get($cache_key);
	return $res if defined $res;

	$args->{source} = 'wiki_page';
	$args->{search} = $args->{page};
	my $data = buzzfeed2::Scraper->get_from_db($args);
	return if !@$data;

	$res = $data->[0]{text};
	$cache->set( $cache_key, $res, CACHE_TIMEOUT );
	return $res;
}

1;
