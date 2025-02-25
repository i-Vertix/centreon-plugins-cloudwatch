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

package centreon::common::xppc::snmp::mode::outputlines;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf("status is '%s'", $self->{result_values}->{status});
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'Output lines ';
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        {
            label => 'status',
            type => 2,
            unknown_default => '%{status} =~ /unknown/i',
            warning_default => '%{status} =~ /rebooting|onBypass/i',
            critical_default => '%{status} =~ /onBattery/i',
            set => {
                key_values => [ { name => 'status' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'load', nlabel => 'lines.output.load.percentage', set => {
                key_values => [ { name => 'upsSmartOutputLoad', no_value => -1 } ],
                output_template => 'load: %.2f %%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100 }
                ]
            }
        },
        { label => 'frequence', nlabel => 'lines.output.frequence.hertz', set => {
                key_values => [ { name => 'upsSmartOutputFrequency', no_value => 0 } ],
                output_template => 'frequence: %.2f Hz',
                perfdatas => [
                    { template => '%.2f', unit => 'Hz' }
                ]
            }
        },
        { label => 'voltage', nlabel => 'lines.output.voltage.volt', set => {
                key_values => [ { name => 'upsSmartOutputVoltage', no_value => 0 } ],
                output_template => 'voltage: %s V',
                perfdatas => [
                    { template => '%s', unit => 'V' }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
    });

    return $self;
}

my $map_status = {
    1 => 'unknown', 2 => 'onLine',
    3 => 'onBattery', 4 => 'onBoost',
    5 => 'sleeping', 6 => 'onBypass',
    7 => 'rebooting', 8 => 'standBy',
    9 => 'onBuck'
};

my $mapping = {
    upsBaseOutputStatus     => { oid => '.1.3.6.1.4.1.935.1.1.1.4.1.1', map => $map_status },
    upsSmartOutputVoltage   => { oid => '.1.3.6.1.4.1.935.1.1.1.4.2.1' }, # in dV
    upsSmartOutputFrequency => { oid => '.1.3.6.1.4.1.935.1.1.1.4.2.2' }, # in tenth of Hz
    upsSmartOutputLoad      => { oid => '.1.3.6.1.4.1.935.1.1.1.4.2.3' }  # in %
};

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_leef(
        oids => [ map($_->{oid} . '.0', values(%$mapping)) ],
        nothing_quit => 1
    );

    my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => '0');
    $result->{upsSmartOutputFrequency} = defined($result->{upsSmartOutputFrequency}) ? $result->{upsSmartOutputFrequency} * 0.1 : 0;
    $result->{upsSmartOutputVoltage} = defined($result->{upsSmartOutputVoltage}) ? $result->{upsSmartOutputVoltage} * 0.1 : 0;
    $result->{status} = $result->{upsBaseOutputStatus};

    $self->{global} = $result;
}
1;

__END__

=head1 MODE

Check output lines metrics.

=over 8

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN (Default: '%{status} =~ /unknown/i').
You can use the following variables: %{status}.

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (Default: '%{status} =~ /rebooting|onBypass/i').
You can use the following variables: %{status}.

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (Default: '%{status} =~ /onBattery/i').
You can use the following variables: %{status}.

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'load', 'voltage', 'current', 'power'.

=back

=cut
