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

package storage::emc::xtremio::restapi::mode::xenvscpu;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments =>
                                {
                                "filter:s@"             => { name => 'filter' },
                                "warning:s"             => { name => 'warning' },
                                "critical:s"            => { name => 'critical' },
                                });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    $self->{filter} = [];
    foreach my $val (@{$self->{option_results}->{filter}}) {
        next if (!defined($val) || $val eq '');
        my @values = split (/,/, $val);
        push @{$self->{filter}}, { filter => $values[0], instance => $values[1] }; 
    }

    if (($self->{perfdata}->threshold_validate(label => 'warning', value => $self->{option_results}->{warning})) == 0) {
       $self->{output}->add_option_msg(short_msg => "Wrong warning threshold '" . $self->{option_results}->{warning} . "'.");
       $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical', value => $self->{option_results}->{critical})) == 0) {
       $self->{output}->add_option_msg(short_msg => "Wrong critical threshold '" . $self->{option_results}->{critical} . "'.");
       $self->{output}->option_exit();
    }
}

sub run {
    my ($self, %options) = @_;
    my $xtremio = $options{custom};
        
    my $urlbase = '/api/json/types/';
    my @items = $xtremio->get_items(url => $urlbase,
                                    obj => 'xenvs');

    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'All Xenvs CPU Usage are OK');

    foreach my $item (@items) {
        next if ($self->check_filter(section => 'cpu', instance => $item));
        my $details = $xtremio->get_details(url  => $urlbase,
                                            obj  => 'xenvs',
                                            name => $item);

        $self->{output}->output_add(long_msg => sprintf("Xenvs '%s' CPU Usage is %i%%",
                                                        $item,
                                                        $details->{'cpu-usage'}));


        my $exit = $self->{perfdata}->threshold_check(value => $details->{'cpu-usage'}, threshold => [ { label => 'critical', exit_litteral => 'critical' }, { label => 'warning', exit_litteral => 'warning' } ]);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity => $exit,
                                        short_msg => sprintf("Xenvs '%s' cpu-Usage is %i%%",
                                                             $item,
                                                             $details->{'cpu-usage'}));
        }
        $self->{output}->perfdata_add(label => 'cpu_' . $item, unit => '%',
                                      value => $details->{'cpu-usage'},
                                      warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning'),
                                      critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical'),
                                      min => 0, max => 100);
    }          

    $self->{output}->display();
    $self->{output}->exit();

}

sub check_filter {
    my ($self, %options) = @_;

    foreach (@{$self->{filter}}) {
        if ($options{section} =~ /$_->{filter}/) {
            if (!defined($options{instance}) && !defined($_->{instance})) {
                $self->{output}->output_add(long_msg => sprintf("Skipping $options{section} section."));
                return 1;
            } elsif (defined($options{instance}) && $options{instance} =~ /$_->{instance}/) {
                $self->{output}->output_add(long_msg => sprintf("Skipping $options{section} section $options{instance} instance."));
                return 1;
            }
        }
    }
    
    return 0;
}

1;

__END__

=head1 MODE

Check Xenvs CPU usage 

=over 8

=item B<--filter>

Filter some parts (comma seperated list)
You can also exclude items from specific instances: --filter=cpu,XENVS-NAME-NUMBER

=item B<--warning>

Value to trigger a warning alarm on CPU usage 

=item B<--critical>

Value to trigger a critical alarm on CPU usage

=back

=cut
