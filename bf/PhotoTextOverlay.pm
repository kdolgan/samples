package buzzfeed2::image::PhotoTextOverlay;

use strict;
use warnings;

use Image::Magick;
use Text::Wrapper;
use File::Slurp qw(read_file);
use Data::Dumper;

use Error qw(:try);

use buzzfeed2::Config;
use buzzfeed::mvc::Action;
use buzzfeed2::image::AmazonS3;
use buzzfeed2::model::BFDB;
use buzzfeed2::image::BFImage;
use buzzfeed2::File::ImageIO2;

##########

use constant BG_COLOR  => '#FF000066';
use constant FONT      => 'DejaVu-Sans-Bold';
use constant FONT_SIZE => 30;

sub text_over_image {
	my ( $self, $img_data ) = @_;
	return if ( !$img_data );

	my $img_body = buzzfeed2::File::ImageIO2->slurp( $img_data->{img_path} );
	my $img_text = $img_data->{img_text};
	my $img      = new Image::Magick;
	$img->BlobToImage($img_body);

	my $args = {
		bg_color  => BG_COLOR,
		font      => FONT,
		font_size => FONT_SIZE
	};
	$self->annotate_image( $img, $img_text, $args );
	my $blob = $img->ImageToBlob();
	return $blob;
}

sub get_image_data {
	my ( $self, $buzz ) = @_;
	my ( $img_file, $img_text, $img_uri );
	my $dbh = buzzfeed2::model::BFDB->connect();
	$img_file = $buzz->{image_big};
	if ( !$img_file ) {
		my $sql = "SELECT c.campaignid, s.image_buzz, s.added
			FROM campaign c
			LEFT JOIN sub_buzz_map m ON m.campaign_id=c.campaignid
			LEFT JOIN sub_buzz s ON s.id=m.sub_buzz_id
			WHERE campaignid=?
			ORDER BY added DESC LIMIT 1";
		my $sth = $dbh->prepare($sql);
		$sth->execute( $buzz->{campaignid} );
		my $row = $sth->fetchrow_hashref();
		return if ( !$row );
		$img_file = $row->{image_buzz};
	}
	return if ( !$img_file );

	my $img_path = buzzfeed2::Config::IMAGE_PATH . $img_file;
	$img_path =~ s!static/static!static!;
	my $img_data = {
		img_path => $img_path,
		img_text => $buzz->{name},
		img_uri  => $buzz->{uri}
	};
	return $img_data;
}

sub annotate_image {
	my ( $self, $img, $text, $args ) = @_;
	my $bg_color  = $args->{bg_color};
	my $font_size = $args->{font_size} || FONT_SIZE;
	my %param     = (
		gravity   => 'West',
		x         => 20,
		fill      => 'white',
		antialias => 'true',
	);

	my ( $p_width, $p_height ) = ( 600, 1000 );
	$img->Resize( geometry => $p_width . 'x' . $p_height );

	my ( $width, $height ) = $img->Get( 'width', 'height' );

	my $text_columns = int( $width / $font_size * 1.5 );
	my $wrapper = Text::Wrapper->new( columns => $text_columns );
	$text = $wrapper->wrap($text);
	my @lines = split( /\n/, $text );
	my $lines_count = scalar(@lines);

	my $bg_heihgt = ( $lines_count + 1 ) * $font_size;
	my $bg_width  = $width;

	my ( $x1, $x2 ) = ( 1, $width );
	my $y1 = int( $height / 2 - $bg_heihgt / 2 - $font_size );
	my $y2 = int( $height / 2 + $bg_heihgt / 2 );

	$img->Draw( fill => $bg_color, primitive => 'rectangle', points => "$x1,$y1 $x2,$y2" );

	$param{text} = $text;
	if ( $args->{font} ) {
		$param{font} = $args->{font};
	}
	$param{pointsize} = $font_size;
	$img->Annotate(%param);
}

sub generate_titled_image {
	my ( $self, $img_data, $blob ) = @_;
	my $upload_args = {
		image_blob => $blob,
		img_path   => $img_data->{img_path},
		origin     => 'enhanced',
		type       => 'campaign_images',
	};
	my $upload_img_data = buzzfeed2::image::BFImage->uploadImage($upload_args);
	my $save_image_args = {
		image_name     => $img_data->{img_uri} . '-t',
		image_web_path => $upload_img_data->{image_url},
		origin         => 'enhanced',
		type           => 'campaign_images',
		thumbnail      => 0,
	};
	my $saved_img_data = buzzfeed2::image::BFImage->save_image($save_image_args);
	return $saved_img_data;
}

sub get_titled_img_url {
	my ( $self, $buzz ) = @_;
	my $buzz_img_url;
	my $campaign_image = $self->image_exists( $buzz->{campaignid} );
	if ($campaign_image) {
		$buzz_img_url = $campaign_image;
	}
	else {
		my $img_data = $self->get_image_data($buzz);
		throw buzzfeed2::error::FileNotFound("BuzzError: the buzz specified has no image") unless $img_data;
		my $blob = $self->text_over_image($img_data);
		my $saved_img_data = $self->generate_titled_image( $img_data, $blob );
		$buzz_img_url = $saved_img_data->{enhanced_image}->{image_url};
		$self->save_campaign_image( $buzz->{campaignid}, $buzz_img_url );
	}
	return $buzz_img_url;
}

sub image_exists {
	my ( $self, $buzz_id ) = @_;
	my $dbh = buzzfeed2::model::BFDB->connect();
	my $sql = "SELECT * FROM campaign_image_share WHERE campaign_id=?";
	my $sth = $dbh->prepare($sql);
	$sth->execute($buzz_id);
	my $campaign_image;
	if ( my $row = $sth->fetchrow_hashref() ) {
		$campaign_image = $row->{image};
	}
	return $campaign_image;
}

sub save_campaign_image {
	my ( $self, $buzz_id, $image ) = @_;
	my $dbh = buzzfeed2::model::BFDB->connect();
	my $sql = "INSERT INTO campaign_image_share (campaign_id, image) VALUES(?, ?)";
	$dbh->do( $sql, {}, $buzz_id, $image );
}

1;

