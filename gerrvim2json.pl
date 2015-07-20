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

use strict;
use warnings;

use Encode;
use JSON;

my %comments;
my $blockid;
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
    my %c = (message => buf2str);
    if ($lineend - $linebgn == 1) {
        $c{line} = $linebgn;
    } else {
        $c{range} = {start_line => $linebgn, end_line => $lineend};
    };
    ($c{in_reply_to} = $1) if ($blockid =~ /^R(.*)$/);
    push @{$comments{$filename}}, \%c;
}

while (<>) {
    chomp;
    if (/^-{5}BEGIN (\w+) (.*) (\d+) (\d+)-{5}$/) {
        $verbatim_block = 1;
        ($main_message = buf2str) unless $blockn;
        $blockn++;
        comment_done if defined $filename;
        $blockid = $1;
        $filename = $2;
        $linebgn = $3;
        $lineend = $4;
    };
    push @buf, $_ unless $verbatim_block;
    if (/^-{5}END-{5}$/) {
        $verbatim_block = 0;
    };
};
comment_done if defined $filename;
($main_message = buf2str) if !$blockn;

my %result = (comments => \%comments);
($result{message} = $main_message) if $main_message;
print encode_json(\%result);
