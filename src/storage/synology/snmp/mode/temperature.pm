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

package storage::synology::snmp::mode::temperature;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_temp_perfdata {
    my ($self, %options) = @_;

    $self->{output}->perfdata_add(
        nlabel => $self->{nlabel},
        unit => 'C',
        instances => 'system',
        value => $self->{result_values}->{temperature},
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $self->{thlabel}),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $self->{thlabel})
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'temperature', nlabel => 'hardware.temperature.celsius', set => {
                key_values => [ { name => 'temperature' } ],
                output_template => 'system temperature: %s C',
                closure_custom_perfdata => $self->can('custom_temp_perfdata')
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

sub manage_selection {
    my ($self, %options) = @_;

    my $oid_synoSystemtemperature = '.1.3.6.1.4.1.6574.1.2.0'; # in Celsius

    my $snmp_result = $options{snmp}->get_leef(
        oids => [ $oid_synoSystemtemperature ],
        nothing_quit => 1
    );

    $self->{global} = {
        temperature => $snmp_result->{$oid_synoSystemtemperature}
    };
}

1;

__END__

=head1 MODE

Check temperature (SYNOLOGY-SYSTEM-MIB).

=over 8

=item B<--warning-temperature>

Warning threshold in celsius degrees.

=item B<--critical-temperature>

Critical threshold in celsius degrees.

=back

=cut
