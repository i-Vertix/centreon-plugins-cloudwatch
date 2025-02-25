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

package os::linux::local::mode::storage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_usage_perfdata {
    my ($self, %options) = @_;

    my $label = $self->{nlabel};
    my $value_perf = $self->{result_values}->{used};
    if (defined($self->{instance_mode}->{option_results}->{free})) {
        $label = 'storage.space.free.bytes';
        $value_perf = $self->{result_values}->{free};
    }

    my %total_options = ();
    if ($self->{instance_mode}->{option_results}->{units} eq '%') {
        $total_options{total} = $self->{result_values}->{total};
        $total_options{cast_int} = 1;
    }

    $self->{output}->perfdata_add(
        nlabel => $label,
        unit => 'B',
        instances => $self->{result_values}->{display},
        value => $value_perf,
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $self->{thlabel}, %total_options),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $self->{thlabel}, %total_options),
        min => 0, max => $self->{result_values}->{total}
    );
}

sub custom_usage_threshold {
    my ($self, %options) = @_;

    my ($exit, $threshold_value);
    $threshold_value = $self->{result_values}->{used};
    $threshold_value = $self->{result_values}->{free} if (defined($self->{instance_mode}->{option_results}->{free}));
    if ($self->{instance_mode}->{option_results}->{units} eq '%') {
        $threshold_value = $self->{result_values}->{prct_used};
        $threshold_value = $self->{result_values}->{prct_free} if (defined($self->{instance_mode}->{option_results}->{free}));
    }
    $exit = $self->{perfdata}->threshold_check(value => $threshold_value, threshold => [ { label => 'critical-' . $self->{thlabel}, exit_litteral => 'critical' }, { label => 'warning-'. $self->{thlabel}, exit_litteral => 'warning' } ]);
    return $exit;
}

sub custom_usage_output {
    my ($self, %options) = @_;

    my ($total_size_value, $total_size_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{total});
    my ($total_used_value, $total_used_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{used});
    my ($total_free_value, $total_free_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{free});
    return sprintf(
        'Usage Total: %s Used: %s (%.2f%%) Free: %s (%.2f%%)',
        $total_size_value . " " . $total_size_unit,
        $total_used_value . " " . $total_used_unit, $self->{result_values}->{prct_used},
        $total_free_value . " " . $total_free_unit, $self->{result_values}->{prct_free}
    );
}

sub custom_usage_calc {
    my ($self, %options) = @_;

    if ($options{new_datas}->{$self->{instance} . '_total'} == 0) {
        $self->{error_msg} = "total size is 0";
        return -2;
    }
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    $self->{result_values}->{total} = $options{new_datas}->{$self->{instance} . '_total'};
    $self->{result_values}->{used} = $options{new_datas}->{$self->{instance} . '_used'};
    $self->{result_values}->{free} = $options{new_datas}->{$self->{instance} . '_free'};
    $self->{result_values}->{prct_used} = $self->{result_values}->{used} * 100 / ($self->{result_values}->{used} + $self->{result_values}->{free});
    $self->{result_values}->{prct_free} = 100 - $self->{result_values}->{prct_used};

    return 0;
}

sub prefix_disks_output {
    my ($self, %options) = @_;
    
    return "Storage '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'disks', type => 1, cb_prefix_output => 'prefix_disks_output', message_multiple => 'All storages are ok' }
    ];
    
    $self->{maps_counters}->{disks} = [
        { label => 'usage', nlabel => 'storage.space.usage.bytes', set => {
                key_values => [ { name => 'display' }, { name => 'used' }, { name => 'free' }, { name => 'total' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold')
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-type:s'        => { name => 'filter_type' },
        'filter-fs:s'          => { name => 'filter_fs' },
        'exclude-fs:s'         => { name => 'exclude_fs' },
        'filter-mountpoint:s'  => { name => 'filter_mountpoint' },
        'exclude-mountpoint:s' => { name => 'exclude_mountpoint' },
        'units:s'              => { name => 'units', default => '%' },
        'free'                 => { name => 'free' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($stdout, $exit_code) = $options{custom}->execute_command(
        command => 'df',
        command_options => '-P -k -T 2>&1',
        no_quit => 1
    );

    $self->{disks} = {};
    my @lines = split /\n/, $stdout;
    foreach my $line (@lines) {
        next if ($line !~ /^(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(.*)/);
        my ($fs, $type, $size, $used, $available, $percent, $mount) = ($1, $2, $3, $4, $5, $6, $7);

        next if (defined($self->{option_results}->{filter_fs}) && $self->{option_results}->{filter_fs} ne '' &&
            $fs !~ /$self->{option_results}->{filter_fs}/);
        next if (defined($self->{option_results}->{exclude_fs}) && $self->{option_results}->{exclude_fs} ne '' &&
            $fs =~ /$self->{option_results}->{exclude_fs}/);
        next if (defined($self->{option_results}->{filter_type}) && $self->{option_results}->{filter_type} ne '' &&
            $type !~ /$self->{option_results}->{filter_type}/);
        next if (defined($self->{option_results}->{filter_mountpoint}) && $self->{option_results}->{filter_mountpoint} ne '' &&
            $mount !~ /$self->{option_results}->{filter_mountpoint}/);
        next if (defined($self->{option_results}->{exclude_mountpoint}) && $self->{option_results}->{exclude_mountpoint} ne '' &&
            $mount =~ /$self->{option_results}->{exclude_mountpoint}/);

        $self->{disks}->{$mount} = {
            display => $mount,
            fs => $fs,
            type => $type,
            total => $size * 1024,
            used => $used * 1024,
            free => $available * 1024
        };
    }

    if (scalar(keys %{$self->{disks}}) <= 0) {
        if ($exit_code != 0) {
            $self->{output}->output_add(long_msg => "command output:" . $stdout);
        }
        $self->{output}->add_option_msg(short_msg => "No storage found (filters or command issue)");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check storage usages.

Command used: df -P -k -T 2>&1

=over 8

=item B<--warning-usage>

Warning threshold.

=item B<--critical-usage>

Critical threshold.

=item B<--units>

Units of thresholds (Default: '%') ('%', 'B').

=item B<--free>

Thresholds are on free space left.

=item B<--filter-mountpoint>

Filter filesystem mount point (regexp can be used).

=item B<--exclude-mountpoint>

Exclude filesystem mount point (regexp can be used).

=item B<--filter-type>

Filter filesystem type (regexp can be used).

=item B<--filter-fs>

Filter filesystem (regexp can be used).

=item B<--exclude-fs>

Exclude filesystem (regexp can be used).

=back

=cut
