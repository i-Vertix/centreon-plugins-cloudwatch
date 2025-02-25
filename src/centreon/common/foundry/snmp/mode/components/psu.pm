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

package centreon::common::foundry::snmp::mode::components::psu;

use strict;
use warnings;
use centreon::common::foundry::snmp::mode::components::resources qw($map_status);

my $mapping = {
    snChasPwrSupply2Description => { oid => '.1.3.6.1.4.1.1991.1.1.1.2.2.1.3' },
    snChasPwrSupply2OperStatus  => { oid => '.1.3.6.1.4.1.1991.1.1.1.2.2.1.4', map => $map_status }
};
my $oid_snChasPwrSupply2Entry = '.1.3.6.1.4.1.1991.1.1.1.2.2.1';

sub load {
    my ($self) = @_;
    
    push @{$self->{request}}, {
        oid => $oid_snChasPwrSupply2Entry,
        start => $mapping->{snChasPwrSupply2Description}->{oid}
    };
}

sub check {
    my ($self) = @_;
    
    $self->{output}->output_add(long_msg => 'checking power supplies');
    $self->{components}->{psu} = { name => 'psu', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'psu'));

    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{results}->{$oid_snChasPwrSupply2Entry}})) {
        next if ($oid !~ /^$mapping->{snChasPwrSupply2OperStatus}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $self->{snmp}->map_instance(mapping => $mapping, results => $self->{results}->{$oid_snChasPwrSupply2Entry}, instance => $instance);

        next if ($self->check_filter(section => 'psu', instance => $instance));
        $self->{components}->{psu}->{total}++;
        
        $self->{output}->output_add(
            long_msg => sprintf(
                "power supply '%s' status is '%s' [instance: %s].",
                $result->{snChasPwrSupply2Description},
                $result->{snChasPwrSupply2OperStatus},
                $instance
            )
        );
        my $exit = $self->get_severity(label => 'default', section => 'psu', value => $result->{snChasPwrSupply2OperStatus});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity =>  $exit,
                short_msg => sprintf(
                    "power supply '%s' status is '%s'",
                    $result->{snChasPwrSupply2Description},
                    $result->{snChasPwrSupply2OperStatus}
                )
            );
        }
    }
}

1;
