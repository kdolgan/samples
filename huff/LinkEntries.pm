package LinkEntries;

use strict;
use warnings;
use Data::Dumper;

use MT;
use MT::Entry;

sub get_linked_ids{
    my ($entry, $args, $link_type) = @_;
    my ($entry_id, $entry_blog_id) = ($entry->id, $entry->blog_id);

    my $where_and = '';
    if($args && $args->{blog_id}){
        $where_and = ' AND e.entry_blog_id IN('.$args->{blog_id}.')';
    }
	if($args && $args->{"stars_more"}) {
		$where_and .= ' AND s.entry_stars_stars >= '.$args->{"stars_more"};
	}
	if($args && $args->{"modified_last_hours"}){
		$where_and .= ' AND e.entry_modified_on BETWEEN (NOW() - INTERVAL '.$args->{"modified_last_hours"}.' HOUR) AND NOW()';
	}

	my $limit = ($args && $args->{"limit"}) ? "LIMIT ".$args->{limit} : "";
    my $order = ' created_on DESC ';
    if($args && $args->{blog_id} eq '3'){
        $order = ' stars DESC, '.$order;
    }

    use HP::DBH;
    my $hp_dbh = HP::DBH->new();
    my $dbh = $hp_dbh->get_dbh(for => "slave-db");

    my $ids_for_indirect_links = $dbh->selectcol_arrayref("
                        SELECT DISTINCT l.linked_entry_id
                        FROM hp_linked_entries l
                        LEFT JOIN mt_entry e ON l.linked_entry_id=e.entry_id
                        WHERE l.entry_id = $entry_id
                        AND e.entry_blog_id != $entry_blog_id 
        ", {Columns => [1]}) || [];
    my $sql;
    my $always_execute_this_branch = 1;

    #if(!@$ids_for_indirect_links){
    if ($always_execute_this_branch) {
        # Get only directly linked entrieskeys %stashed_entries
        $sql = qq~
                SELECT DISTINCT l.linked_entry_id, e.entry_created_on created_on, s.entry_stars_stars stars
                FROM hp_linked_entries l
                LEFT JOIN mt_entry e ON l.linked_entry_id = e.entry_id
                LEFT JOIN mt_entry_stars s ON s.entry_stars_id = l.linked_entry_id
                WHERE l.entry_id = $entry_id
                AND l.linked_entry_id != $entry_id
					AND e.entry_status = 2
                    $where_and
                ORDER BY
                    $order
                $limit
                ~;
    }
    else{
        # The first subquery gets entries linked indirectly - i.e. blogs associated with linked news or vice versa
        # The second subquery gets directly linked entries 
        my $ids = join(',', @$ids_for_indirect_links);
        $sql = qq~
            (
                SELECT DISTINCT l.linked_entry_id, e.entry_created_on created_on, s.entry_stars_stars stars
                FROM hp_linked_entries l
                LEFT JOIN mt_entry e ON l.linked_entry_id=e.entry_id
                LEFT JOIN mt_entry_stars s ON s.entry_stars_id = l.linked_entry_id
                WHERE l.entry_id in($ids)
                AND e.entry_blog_id = $entry_blog_id
                AND l.linked_entry_id != $entry_id
                $where_and
            )
            UNION
            (
                SELECT DISTINCT l.linked_entry_id, e.entry_created_on created_on, s.entry_stars_stars stars
                FROM hp_linked_entries l
                LEFT JOIN mt_entry e ON l.linked_entry_id = e.entry_id
                LEFT JOIN mt_entry_stars s ON s.entry_stars_id = l.linked_entry_id
                WHERE l.entry_id = $entry_id
                AND l.linked_entry_id != $entry_id
                $where_and
            )
            ORDER BY
                $order
            $limit
            ~;
    }
    my $linked = $dbh->selectcol_arrayref($sql, {Columns => [1]}) || [];
    return @$linked;
}

sub get_primary_verticals {
    return unless (@_);
    use HP::DBH;
    my $hp_dbh = HP::DBH->new();
    my $dbh = $hp_dbh->get_dbh(for => "slave-db");

    my $id_list=join(",", @_);
    my $sql="SELECT vertical_label, placement_entry_id, placement_blog_id
          FROM mt_placement 
          INNER JOIN mt_vertical ON (
     	   	vertical_blog_category_id=placement_category_id 
	  OR 
		vertical_news_category_id=placement_category_id
	  )
          WHERE 
                placement_is_primary=1
          AND
                placement_entry_id in ($id_list)";
    my $linked = $dbh->selectall_arrayref($sql) || [];

    return @$linked;
}

sub has_link_entries {
    my ($ctx, $args, $cond) = @_;

    my $entry = $ctx->stash("entry");

    return 0 if !$entry;
	my $limit = $args->{"limit"} if defined($args->{"limit"}) || 0;
	$args->{"limit"} = undef;
    my @linked_ids = get_linked_ids($entry, $args);
	#checking which entries from those entries have tag @sponsor
	my @sponsored = ();
	if (@linked_ids)
	{
	    use HP::DBH;
	    my $hp_dbh = HP::DBH->new();
	    my $dbh = $hp_dbh->get_dbh(for => "slave-db");
        my $ids = join(',', @linked_ids);
		my $sql = qq~
			SELECT
				mo.`objecttag_object_id`				
			FROM
				mt_objecttag mo
			INNER JOIN
				mt_tag mt
			ON
				mo.objecttag_tag_id = mt.tag_id
			INNER JOIN
				mt_entry me
			ON
				me.entry_id = mo.`objecttag_object_id`
			WHERE
				mo.`objecttag_object_id` IN ($ids)
				AND mo.`objecttag_object_datasource` = "entry"
				AND mt.tag_name = '\@sponsor'
			ORDER BY
				me.entry_created_on DESC
		~;
	    @sponsored = @{$dbh->selectcol_arrayref($sql, {Columns => [1]}) || ()};
	    $ctx->stash('sponsored', \@sponsored);
	}
	#hack, force limit for linked blogs, as we have hardcoded logic with show_expanded field from mt_entry_extra
	#for specified entry, so checking show_expanded_count right here
	if ($args->{"recalculate_limit"} && $limit)
	{
	    use huff::EntryExtra;
	    my ($extra) = huff::EntryExtra->load({ id => $entry->id });
	    my $show_expanded_count = 0;
	
	    if( $extra && $extra->expanded ){
	        $show_expanded_count = $extra->expanded;
	
	        if( (scalar(@linked_ids) - $show_expanded_count) % 2 == 1 ){
	            # make sure we have even number of collapsed entries
	            $show_expanded_count++;
	         }
	    }elsif( scalar(@linked_ids) < 5 ) {
	        $show_expanded_count = scalar(@linked_ids);
	    }elsif( scalar(@linked_ids) % 2 ) {
	        #odd numbered entries, expand the first entry
	        $show_expanded_count = 1;
	    }
	    if ($show_expanded_count < scalar @sponsored)
	    {
	    	$show_expanded_count = scalar @sponsored;#keys %sponsored
	    }
        if( (scalar(@linked_ids) - $show_expanded_count) % 2 == 1 ){
            # make sure we have even number of collapsed entries
            $show_expanded_count++;
         }
	    if ((scalar(@linked_ids) <= $show_expanded_count) || (scalar(@linked_ids) <= $show_expanded_count + $limit))
	    {
	    	$limit = scalar(@linked_ids);
	    }
	    else
	    {
	    	$limit = $show_expanded_count + $limit;
	    }
	    $ctx->stash('show_expanded_count', $show_expanded_count);
	}
    $ctx->stash('get_number_linked_entries', scalar @linked_ids);
    $ctx->stash('all_linked_ids', \@linked_ids);
    $limit = $limit > scalar @linked_ids ? scalar @linked_ids : $limit;
    $ctx->stash('real_limit', $limit);
    my @linked_ids_cutted = $limit ? @linked_ids[0..($limit - 1)] : @linked_ids;
    $ctx->stash('linked_ids', \@linked_ids_cutted);

    return scalar @linked_ids;
}

sub linked_entries {
    my ($ctx, $args, $cond) = @_;
    
    my ($ctx, $args, $cond) = @_;

    my $res = "";
    my $entry = $ctx->stash("entry");

    return $res if !$entry;

    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');

    use huff::EntryExtra;
    my ($extra) = huff::EntryExtra->load({ id => $entry->id });

    return $res
        if (!$ctx->stash('linked_ids') || ref($ctx->stash('linked_ids')) ne 'ARRAY' || ! @{$ctx->stash('linked_ids')});

    my %entries = map {$_->id => $_} MT::Entry->load({id => $ctx->stash('all_linked_ids')});
	my $linked_ids = $ctx->stash('linked_ids');
    my $show_expanded_count = $ctx->stash('show_expanded_count') ? $ctx->stash('show_expanded_count') : 0;
	if (!$show_expanded_count)
	{
	    if( $extra && $extra->expanded ){
	        $show_expanded_count = $extra->expanded;	
	        if( (scalar(@$linked_ids) - $show_expanded_count) % 2 == 1 ){
	            # make sure we have even number of collapsed entries
	            $show_expanded_count++;
	         }
	    }elsif( scalar(@$linked_ids) < 5 ) {
	        $show_expanded_count = scalar(@$linked_ids);
	    }elsif( scalar(@$linked_ids) % 2 ) {
	        #odd numbered entries, expand the first entry
	        $show_expanded_count = 1;
	    }
    }

	my $sponsored = $ctx->stash("sponsored") || [];
	my $limit = $ctx->stash("real_limit") || 0;
	my $limit_setup = $limit > 0;
	my %sponsored_tmp = map {$_ => $_} @$sponsored;
	my @entry_ids = (@$sponsored, @$linked_ids);
	my $last_sponsored = scalar keys %sponsored_tmp ? $entry_ids[(scalar keys %sponsored_tmp) - 1] : 0;
    foreach (0..@entry_ids-1) {
		my $e = $entry_ids[$_];
		if ($limit_setup && !$limit)
		{
			last;
		}
		next if (($_ >= (scalar keys %sponsored_tmp)) && (defined $sponsored_tmp{$e}));
        local $ctx->{__stash}{entry} = $entries{$e};
        $ctx->stash("show_expanded", $show_expanded_count);
	    $ctx->stash("sponsored", defined $sponsored_tmp{$e});
	    $ctx->stash("last_sponsored", $last_sponsored == $e);
        my $out = $builder->build($ctx, $tokens);
        return $ctx->error($builder->errstr) if !defined($out);
        $res .= $out;
        $show_expanded_count--;
        --$limit if $limit_setup;
    }

    return $res;
}


1;
