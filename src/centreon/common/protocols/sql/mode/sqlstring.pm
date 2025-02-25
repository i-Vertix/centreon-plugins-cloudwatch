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

package centreon::common::protocols::sql::mode::sqlstring;

use base qw(centreon::plugins::templates::counter);
use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'rows', type => 1, message_multiple => "SQL Query is OK" },
    ];

    $self->{maps_counters}->{rows} = [
        { label => 'string', type => 2, set => {
                key_values => [ { name => 'key_field' }, { name => 'value_field' } ],
                closure_custom_output => $self->can('custom_string_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng,
                closure_custom_perfdata => sub { return 0; }
            }
        }
    ];
}

sub custom_string_output {
    my ($self, %options) = @_;

    my $msg;
    my $message;

    if (defined($self->{instance_mode}->{option_results}->{printf_format}) && $self->{instance_mode}->{option_results}->{printf_format} ne '') {
        eval {
            local $SIG{__WARN__} = sub { $message = $_[0]; };
            local $SIG{__DIE__} = sub { $message = $_[0]; };
            $msg = sprintf("$self->{instance_mode}->{option_results}->{printf_format}", $self->{result_values}->{ $self->{instance_mode}->{printf_value} });
        };
    } else {
        $msg = sprintf("'%s'", $self->{result_values}->{value_field});
    }

    if (defined($message)) {
        $self->{output}->output_add(long_msg => 'output value issue: ' . $message);
    }

    return $msg;
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'sql-statement:s'    => { name => 'sql_statement' },
        'key-column:s'       => { name => 'key_column' },
        'value-column:s'     => { name => 'value_column' },
        'printf-format:s'    => { name => 'printf_format' },
        'printf-value:s'     => { name => 'printf_value' },
        'dual-table'         => { name => 'dual_table' },
        'empty-sql-string:s' => { name => 'empty_sql_string', default => 'No row returned or --key-column/--value-column do not correctly match selected field' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    if (!defined($self->{option_results}->{sql_statement}) || $self->{option_results}->{sql_statement} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify '--sql-statement' option.");
        $self->{output}->option_exit();
    }

    $self->{printf_value} = 'value_field';
    if (defined($self->{option_results}->{printf_value}) && $self->{option_results}->{printf_value} ne '') {
        $self->{printf_value} = $1
            if ($self->{option_results}->{printf_value} =~ /\$self->{result_values}->{(value_field|key_field)}/);
        $self->{printf_value} = $1
            if ($self->{option_results}->{printf_value} =~ /\%{(value_field|key_field)}/);
        $self->{printf_value} = $1
            if ($self->{option_results}->{printf_value} =~ /\%\((value_field|key_field)\)/);
    }
}

sub manage_selection {
    my ($self, %options) = @_;

    $options{sql}->connect();
    $options{sql}->query(query => $self->{option_results}->{sql_statement});
    $self->{rows} = {};
    my $row_count = 0;

    while (my $row = $options{sql}->fetchrow_hashref()) {
        if (defined($self->{option_results}->{dual_table})) {
            $row->{$self->{option_results}->{value_column}} = delete $row->{keys %{$row}};
            foreach (keys %{$row}) {
                $row->{$self->{option_results}->{value_column}} = $row->{$_};
            }
        }
        if (!defined($self->{option_results}->{key_column})) {
            $self->{rows}->{$self->{option_results}->{value_column} . $row_count} = {
                key_field => $row->{ $self->{option_results}->{value_column} },
                value_field => $row->{ $self->{option_results}->{value_column} }
            };
            $row_count++;
        } else {
            $self->{rows}->{$self->{option_results}->{key_column} . $row_count} = {
                key_field => $row->{ $self->{option_results}->{key_column} },
                value_field => $row->{ $self->{option_results}->{value_column} }
            };
            $row_count++;
        }
    }

    $options{sql}->disconnect();
    if (scalar(keys %{$self->{rows}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => $self->{option_results}->{empty_sql_string});
        $self->{output}->option_exit();
    }

}

1;

__END__

=head1 MODE

Check SQL statement to query string pattern (You cannot have more than to fiels in select)

=over 8

=item B<--sql-statement>

SQL statement that returns a string.

=item B<--key-column>

Key column (must be one of the selected field). NOT mandatory if you select only one field

=item B<--value-column>

Value column (must be one of the selected field). MANDATORY

=item B<--printf-format>

Specify a custom output message relying on printf formatting. If this option is set --printf-value is mandatory.

=item B<--printf-value>

Specify scalar used to replace in printf. If this option is set --printf-format is mandatory.
(Can be: %{key_field}, %{value_field})

=item B<--warning-string>

Define the conditions to match for the status to be WARNING.
(Can be: %{key_field}, %{value_field})
e.g --warning-string '%{key_field} eq 'Central' && %{value_field} =~ /127.0.0.1/'

=item B<--critical-string>

Define the conditions to match for the status to be CRITICAL
(Can be: %{key_field} or %{value_field})

=item B<--dual-table>

Set this option to ensure compatibility with dual table and Oracle.

=item B<--empty-sql-string>

Set this option to change the output message when the sql statement result is empty.
(Default: 'No row returned or --key-column/--value-column do not correctly match selected field')

=back

=cut
