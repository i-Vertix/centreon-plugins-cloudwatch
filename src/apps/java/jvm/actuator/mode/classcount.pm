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

package apps::java::jvm::actuator::mode::classcount;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub prefix_global_output {
    my ($self, %options) = @_;
    
    return 'Class ';
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'current', nlabel => 'class.loaded.current.count', set => {
                key_values => [ { name => 'current' } ],
                output_template => 'current: %d',
                perfdatas => [
                    { template => '%d', min => 0 }
                ]
            }
        },
        { label => 'unloaded', nlabel => 'class.unloaded.count', set => {
                key_values => [ { name => 'unloaded', diff => 1 } ],
                output_template => 'unloaded: %d',
                perfdatas => [
                    { template => '%d', min => 0 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request_api(endpoint => '/metrics/jvm.classes.unloaded');
    $self->{global} = { unloaded => $result->{measurements}->[0]->{value} };

    $result = $options{custom}->request_api(endpoint => '/metrics/jvm.classes.loaded');
    $self->{global}->{current} = $result->{measurements}->[0]->{value};

    $self->{cache_name} = 'jvm_actuactor_' . $self->{mode} . '_' . $options{custom}->get_connection_infos() . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check java class loading.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='current'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'unloaded', 'current'.

=back

=cut
