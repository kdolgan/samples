package buzzfeed2::controller::www::PluginModeration;

use strict;
use warnings;

use Error qw(:try);

use buzzfeed::mvc::Action;
use buzzfeed2::controller::www::AuthController;
use buzzfeed2::PluginConfig;
use buzzfeed2::model::PluginDAO;

use base q/buzzfeed2::controller::www::AuthController/;

=head2 auth_execute

Description: Regenerate plugins

=cut

sub auth_execute {
	my ($self) = @_;

	return $self->_401 unless $self->user_can('plugin_moderation');

	my $actions = { 'generate_plugin' => \&generate_plugin };
	my $action = $self->{cgi}->param('action') || '';
	if ($action) {
		throw buzzfeed2::error::FileNotFound("PluginModerationError: unknown action")
		  unless defined $actions->{$action};
		$actions->{$action}($self);
	}
	else {
		$self->display_plugins_page();
	}
}

sub display_plugins_page {
	my ($self) = @_;
	buzzfeed2::model::PluginDAO->stick_config_in_memcache();
	my $units = buzzfeed2::PluginConfig::PLUGINS->{units};
	$self->{stash}{units} = $units;
	buzzfeed2::controller::BFAuthController::set_root($self);
	$self->{template} = 'public/user/plugin_moderation.tt';
}

sub generate_plugin {
	my ($self) = @_;
	my $plugin = $self->{cgi}->param('plugin') || '';
	buzzfeed2::model::PluginDAO->stick_config_in_memcache();
	my $units = buzzfeed2::PluginConfig::PLUGINS->{units};
	throw buzzfeed2::error::FileNotFound("PluginModerationError: missing plugin") if ( !$plugin || !$units->{$plugin} );
	my $total = 0;
	my $res = buzzfeed2::model::PluginDAO->add_plugin( $plugin, 1 );
	if ( $res && $res->{debug} ) {

		for my $key ( keys %{ $res->{debug} } ) {
			$total += $res->{debug}->{$key};
		}
	}
	$self->{content_type} = 'text/html';
	$self->{body}         = $total;
}

sub _401 {
	my ( $self, $args ) = @_;
	$self->{status} = 401;
	$self->{body}   = 'Unauthorized';
}

1;
