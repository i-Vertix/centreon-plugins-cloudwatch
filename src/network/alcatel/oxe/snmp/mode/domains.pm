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

package network::alcatel::oxe::snmp::mode::domains;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_usage_perfdata {
    my ($self, %options) = @_;

    $self->{output}->perfdata_add(
        nlabel => $self->{nlabel},
        instances => $self->{result_values}->{display},
        value => $self->{result_values}->{used},
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $self->{thlabel}, total => $self->{result_values}->{total}, cast_int => 1),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $self->{thlabel}, total => $self->{result_values}->{total}, cast_int => 1),
        min => 0, max => $self->{result_values}->{total}
    );
}

sub custom_usage_threshold {
    my ($self, %options) = @_;
    
    my $exit = $self->{perfdata}->threshold_check(
        value => $self->{result_values}->{prct_used},
        threshold => [ 
            { label => 'critical-' . $self->{thlabel}, exit_litteral => 'critical' },
            { label => 'warning-' . $self->{thlabel}, exit_litteral => 'warning' } 
        ]
    );
    return $exit;
}

sub custom_usage_output {
    my ($self, %options) = @_;

    my $msg = sprintf("%s Total: %s Used: %s (%.2f%%) Free: %s (%.2f%%)",
                      $self->{result_values}->{label_output},
                      $self->{result_values}->{total},
                      $self->{result_values}->{used}, $self->{result_values}->{prct_used},
                      $self->{result_values}->{free}, $self->{result_values}->{prct_free});
    return $msg;
}

sub custom_cac_usage_calc {
    my ($self, %options) = @_;

    if ($options{new_datas}->{$self->{instance} . '_cacAllowed'} <= 0) {
        $self->{error_msg} = "skipped (no allowed)";
        return -2;
    }
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    $self->{result_values}->{total} = $options{new_datas}->{$self->{instance} . '_cacAllowed'};
    $self->{result_values}->{used} = $options{new_datas}->{$self->{instance} . '_cacUsed'};
    $self->{result_values}->{free} = $self->{result_values}->{total} - $self->{result_values}->{used};
    $self->{result_values}->{prct_free} = $self->{result_values}->{free} * 100 / $self->{result_values}->{total};
    $self->{result_values}->{prct_used} = $self->{result_values}->{used} * 100 / $self->{result_values}->{total};
    $self->{result_values}->{label_output} = $options{extra_options}->{label_output};
    return 0;
}

sub custom_conference_usage_calc {
    my ($self, %options) = @_;

    if ($options{new_datas}->{$self->{instance} . '_confAvailable'} <= 0) {
        $self->{error_msg} = "skipped (no available)";
        return -2;
    }
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    $self->{result_values}->{total} = $options{new_datas}->{$self->{instance} . '_confAvailable'};
    $self->{result_values}->{used} = $options{new_datas}->{$self->{instance} . '_confBusy'};
    $self->{result_values}->{free} = $self->{result_values}->{total} - $self->{result_values}->{used};
    $self->{result_values}->{prct_free} = $self->{result_values}->{free} * 100 / $self->{result_values}->{total};
    $self->{result_values}->{prct_used} = $self->{result_values}->{used} * 100 / $self->{result_values}->{total};
    $self->{result_values}->{label_output} = $options{extra_options}->{label_output};
    return 0;
}

sub custom_dsp_usage_calc {
    my ($self, %options) = @_;

    if ($options{new_datas}->{$self->{instance} . '_dspRessAvailable'} <= 0) {
        $self->{error_msg} = "skipped (no available)";
        return -2;
    }
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    $self->{result_values}->{total} = $options{new_datas}->{$self->{instance} . '_dspRessAvailable'};
    $self->{result_values}->{used} = $options{new_datas}->{$self->{instance} . '_dspRessBusy'};
    $self->{result_values}->{free} = $self->{result_values}->{total} - $self->{result_values}->{used};
    $self->{result_values}->{prct_free} = $self->{result_values}->{free} * 100 / $self->{result_values}->{total};
    $self->{result_values}->{prct_used} = $self->{result_values}->{used} * 100 / $self->{result_values}->{total};
    $self->{result_values}->{label_output} = $options{extra_options}->{label_output};
    return 0;
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'domain', type => 1, cb_prefix_output => 'prefix_domain_output', message_multiple => 'All domains are ok', skipped_code => { -2 => 1, -10 => 1 } }
    ];

    $self->{maps_counters}->{domain} = [
        { label => 'cac-usage', nlabel => 'domain.communications.external.current.count', set => {
                key_values => [ { name => 'cacUsed' }, { name => 'cacAllowed' }, { name => 'display '} ],
                closure_custom_calc => $self->can('custom_cac_usage_calc'),
                closure_custom_calc_extra_options => { label_output => 'External Communication' },
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold'),
            }
        },
        { label => 'cac-overrun', nlabel => 'domain.communications.external.overrun.count', set => {
                key_values => [ { name => 'cacOverrun' } ],
                output_template => 'conference overrun: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'conference-usage', nlabel => 'domain.conference.circuits.current.count', set => {
                key_values => [ { name => 'confBusy' }, { name => 'confAvailable' }, { name => 'display '} ],
                closure_custom_calc => $self->can('custom_conference_usage_calc'),
                closure_custom_calc_extra_options => { label_output => 'Conference circuits' },
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold'),
            }
        },
        { label => 'conf-outoforder', nlabel => 'domain.conference.circuits.outoforder.count', set => {
                key_values => [ { name => 'confOutOfOrder' } ],
                output_template => 'conference out of order: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'dsp-usage', nlabel => 'domain.compressors.current.count', set => {
                key_values => [ { name => 'dspRessBusy' }, { name => 'dspRessAvailable' }, { name => 'display '} ],
                closure_custom_calc => $self->can('custom_dsp_usage_calc'),
                closure_custom_calc_extra_options => { label_output => 'DSP Compressors' },
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold'),
            }
        },
        { label => 'dsp-outofservice', nlabel => 'domain.compressors.outofservice.count', set => {
                key_values => [ { name => 'dspRessOutOfService' } ],
                output_template => 'compressor out of service: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            },
        },
        { label => 'dsp-overrun', nlabel => 'domain.compressors.overrun.count', set => {
                key_values => [ { name => 'dspRessOverrun' } ],
                output_template => 'compressor overrun: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            },
        }
    ];
}

sub prefix_domain_output {
    my ($self, %options) = @_;

    return "Domain '" . $options{instance_value}->{display} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        "filter-domain:s"   => { name => 'filter_domain' },
    });

    return $self;
}

my $mapping = {
    confAvailable        => { oid => '.1.3.6.1.4.1.637.64.4400.1.3.1.2' },
    confBusy             => { oid => '.1.3.6.1.4.1.637.64.4400.1.3.1.3' },
    confOutOfOrder       => { oid => '.1.3.6.1.4.1.637.64.4400.1.3.1.4' },
    dspRessAvailable     => { oid => '.1.3.6.1.4.1.637.64.4400.1.3.1.5' },
    dspRessBusy          => { oid => '.1.3.6.1.4.1.637.64.4400.1.3.1.6' },
    dspRessOutOfService  => { oid => '.1.3.6.1.4.1.637.64.4400.1.3.1.7' },
    dspRessOverrun       => { oid => '.1.3.6.1.4.1.637.64.4400.1.3.1.8' },
    cacAllowed           => { oid => '.1.3.6.1.4.1.637.64.4400.1.3.1.9' },
    cacUsed              => { oid => '.1.3.6.1.4.1.637.64.4400.1.3.1.10' },
    cacOverrun           => { oid => '.1.3.6.1.4.1.637.64.4400.1.3.1.10' }
};

sub manage_selection {
    my ($self, %options) = @_;
 
    my $oid_ipDomainEntry = '.1.3.6.1.4.1.637.64.4400.1.3.1';
    my $snmp_result = $options{snmp}->get_table(
        oid => $oid_ipDomainEntry,
        nothing_quit => 1
    );

    $self->{domain} = {};
    foreach my $oid (keys %$snmp_result) {
        next if ($oid !~ /^$mapping->{cacAllowed}->{oid}\.(\d+)/);
        my $instance = $1;
        my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => $instance);
        if (defined($self->{option_results}->{filter_domain}) && $self->{option_results}->{filter_domain} ne '' &&
            $instance !~ /$self->{option_results}->{filter_domain}/) {
            $self->{output}->output_add(long_msg => "skipping  '" . $instance . "': no matching filter.", debug => 1);
            next;
        }

        $self->{domain}->{$instance} = { 
            display => $instance,
            %{$result}
        };
    }

    if (scalar(keys %{$self->{domain}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No domain found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check Domain usages.

=over 8

=item B<--filter-domain>

Filter by domain (regexp can be used).

=item B<--warning-*>

Warning threshold.
Can be: 'cac-usage' (%), 'conference-usage' (%), 
'cac-overrun' (absolute),  conf-outoforder (absolute),
'dsp-usage' (absolute), 'dsp-outofservice' (absolute),
'dsp-overrun' (absolute)

=item B<--critical-*>

Critical threshold.
Can be: 'cac-usage' (%), 'conference-usage' (%), 
'cac-overrun' (absolute),  conf-outoforder (absolute),
'dsp-usage' (absolute), 'dsp-outofservice' (absolute),
'dsp-overrun' (absolute)

=back

=cut