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

package storage::emc::unisphere::restapi::mode::components::battery;

use strict;
use warnings;
use storage::emc::unisphere::restapi::mode::components::resources qw($health_status);

sub load {
    my ($self) = @_;

    $self->{json_results}->{battery} = $self->{custom}->request_api(method => 'GET', url_path => '/api/types/battery/instances?fields=name,health');
}

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking batteries');
    $self->{components}->{battery} = { name => 'batteries', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'battery'));
    return if (!defined($self->{json_results}->{battery}));

    foreach my $result (@{$self->{json_results}->{battery}->{entries}}) {
        my $instance = $result->{content}->{id};

        next if ($self->check_filter(section => 'battery', instance => $instance));
        $self->{components}->{battery}->{total}++;

        my $health = $health_status->{ $result->{content}->{health}->{value} };
        $self->{output}->output_add(
            long_msg => sprintf(
                "battery '%s' status is '%s' [instance: %s]",
                $result->{content}->{name}, $health, $instance
            )
        );

        my $exit = $self->get_severity(label => 'health', section => 'battery', value => $health);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Battery '%s' status is '%s'", $result->{content}->{name}, $health)
            );
        }
    }
}

1;
