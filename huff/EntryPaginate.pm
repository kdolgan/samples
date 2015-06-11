package MT::Plugin::EntryPaginate;

use strict;
use warnings;

use MT;
use MT::Plugin;
use vars qw(@ISA);
@ISA = qw(MT::Plugin);


my $plugin = new MT::Plugin::EntryPaginate({
    name => 'EntryPaginate',
    description => 'Split entry text into several pages',
});

MT->add_plugin($plugin);

use MT::Template::Context;
use MT::App::CMS;


MT::Template::Context->add_conditional_tag(IfEntryPaginated => sub {
    my ($ctx, $arg) = @_;
    my $e = $ctx->stash('entry');
    return $ctx->_no_entry_error('MTEntryLink') if !$e;
    return 0 unless ($e->text . $e->text_more =~ /<\!--pagebreak-->/);

    my $fulltext = MT::Template::Context::_hdlr_entry_body($ctx, $arg) . MT::Template::Context::_hdlr_entry_more($ctx, $arg);

    my @parts = split('<!--pagebreak-->', join("\r\n\r\n", $fulltext));
    $ctx->stash('entry')->{text_pages} = [ @parts ];
    return (@parts - 1);
});

MT::Template::Context->add_tag(EntryPagesCount => sub {
    my $ctx = shift;
    my $e = $ctx->stash('entry');
    return 0 if !$e;
    return scalar @{$e->{text_pages}};
}); 

MT::Template::Context->add_container_tag(EntryPages => sub {
    my $ctx = shift;
    my $res = '';
    my $pages;

    if ( !$ctx->stash('entry') ) {
        return $res;
    }
    my @pages = @{$ctx->stash('entry')->{text_pages}};
    if (!@pages) {
        return $res;
    }
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    $ctx->stash('default_page', $pages[0]);
    for (my $i = 0; $i < @pages; $i++) {
        $ctx->stash('page_number', $i + 1);
        $ctx->stash('page_text', $pages[$i]);
        defined(my $out = $builder->build($ctx, $tokens))
            or return $ctx->error($builder->errstr);
        $res .= $out;
    }
    $res;
});

MT::Template::Context->add_tag(EntryPageNumber => sub { return $_[0]->stash('page_number'); });
MT::Template::Context->add_tag(EntryPageText => sub { return $_[0]->stash('page_text'); });
MT::Template::Context->add_tag(EntryPageTextDefault => sub { return $_[0]->stash('default_page'); });

1;
