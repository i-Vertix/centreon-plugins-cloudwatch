#
# Copyright 2023 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package apps::cisco::cms::restapi::mode::databasestatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold);

sub custom_status_output {
    my ($self, %options) = @_;

    my $msg = sprintf("master status is '%s', up is '%s' [Sync behind: %s B]",
        $self->{result_values}->{master}, $self->{result_values}->{up}, $self->{result_values}->{sync_behind});
    return $msg;
}

sub custom_status_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{sync_behind} = $options{new_datas}->{$self->{instance} . '_syncBehind'};
    $self->{result_values}->{master} = $options{new_datas}->{$self->{instance} . '_master'};
    $self->{result_values}->{up} = $options{new_datas}->{$self->{instance} . '_up'};
    $self->{result_values}->{hostname} = $options{new_datas}->{$self->{instance} . '_hostname'};
    return 0;
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'nodes', type => 1, cb_prefix_output => 'prefix_node_output', message_multiple => 'All database hosts are ok' },
    ];

    $self->{maps_counters}->{nodes} = [
        { label => 'status', threshold => 0, set => {
                key_values => [ { name => 'syncBehind' }, { name => 'master' }, { name => 'up' },
                    { name => 'hostname' } ],
                closure_custom_calc => $self->can('custom_status_calc'),
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
    ];
}

sub prefix_node_output {
    my ($self, %options) = @_;

    return "Node '" . $options{instance_value}->{hostname} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments =>
                                {
                                    "warning-status:s"      => { name => 'warning_status', default => '' },
                                    "critical-status:s"     => { name => 'critical_status', default => '%{up} !~ /true/i' },
                                });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => ['warning_status', 'critical_status']);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->get_endpoint(method => '/system/database');

    $self->{nodes} = {};

    if (defined($results->{clustered}) && $results->{clustered} ne 'enabled' ) {
        $self->{output}->add_option_msg(short_msg => "Database clustering is not enabled");
        $self->{output}->option_exit();
    }

    foreach my $node (@{$results->{cluster}->{node}}) {
        $self->{nodes}->{$node->{hostname}} = {
            hostname => $node->{hostname},
            master => $node->{master},
            up => $node->{up},
            syncBehind => $node->{syncBehind},
        };
    }

    if (scalar(keys %{$self->{nodes}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No nodes found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check database status.

=over 8

=item B<--warning-status>

Define the conditions to match for the status to be WARNING. (Default: '').
Can use special variables like: %{hostname}, %{master}, %{up}, %{sync_behind}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL. (Default: '%{up} !~ /true/i').
Can use special variables like: %{hostname}, %{master}, %{up}, %{sync_behind}

=back

=cut
