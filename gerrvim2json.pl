#!/usr/bin/env perl
# gerrvim -- Gerrit review's comments preparation helper
# Copyright (C) 2015 Sergey Matveev <stargrave@stargrave.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=pod

=head1 DESCRIPTION

This script converts gerrvim Vim pluging temporary file to JSON suitable
to be published in Gerrit. Input file like this:

    Some main review message.
    It can be multilined.

    -----BEGIN 5e5a5d9ae9339c8f2c5405c8145e61b738953b4e Makefile 27 29-----
    foo: bar
        make -C some thing
    -----END-----
    You must replace make with $(MAKE).

    And I could write it multiline too.


    -----BEGIN 5e5a5d9ae9339c8f2c5405c8145e61b738953b4e Makefile 1 2-----
    #/usr/bin/make
    -----END-----
    Remove that.

is transformed to JSON like this:

    {
      "message": "Some main review message.\nIt can be multilined.",
      "comments": {
        "Makefile": [
          {
            "message": "You must replace make with $(MAKE).\n\nAnd I could write it multiline too.",
            "range": {
              "start_line": "27",
              "end_line": "29"
            }
          },
          {
            "message": "Remove that.",
            "range": {
              "end_line": "2",
              "start_line": "1"
            }
          }
        ]
      }
    }

=head1 INPUT FORMAT

Each comment to lines of some file starts with -----BEGIN----- block.
After BEGIN word, four parts are comming (space separated):

=over 4

=item * Commit's hash. SHA1 in hexadecimal

=item * Path to file inside repository

=item * Linenumber where comment begins

=item * Linenumber where comment ends

=back

After BEGIN goes optional text that won't be included in JSON at all. As
a rule it is just a copy of code to be commented. It ends with -----END-----.

Everything between END of one block and BEGIN of another is treated as a
comment to the block above. Empty newlines at the end are removed.
Optional text before the first BEGIN block is treated as overall review
message.

=cut

use strict;
use warnings;

use Encode;
use JSON;

my %comments;
my $filename = undef;
my $linebgn = undef;
my $lineend = undef;
my $blockn = 0;
my $main_message = undef;
my $verbatim_block = 0;
my @buf;

sub buf2str {
    my $r = join "\n", @buf;
    chomp $r;
    $r =~ s/\n+$//g;
    @buf = ();
    return decode_utf8 $r;
};

sub comment_done {
    ($comments{$filename} = []) unless defined $comments{$filename};
    push @{$comments{$filename}}, {
        range => {start_line => $linebgn, end_line => $lineend},
        message => buf2str,
    };
}

while (<>) {
    chomp;
    if (/^-{5}BEGIN \w{40} (.*) (\d+) (\d+)-{5}$/) {
        $verbatim_block = 1;
        ($main_message = buf2str) unless $blockn;
        $blockn++;
        comment_done if defined $filename;
        $filename = $1;
        $linebgn = $2;
        $lineend = $3;
    };
    push @buf, $_ unless $verbatim_block;
    if (/^-{5}END-{5}$/) {
        $verbatim_block = 0;
    };
};
comment_done;

my %result = (comments => \%comments);
($result{"message"} = $main_message) if $main_message;
print encode_json(\%result);
