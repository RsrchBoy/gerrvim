#!/bin/sh
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

[ -n "$PERL" ] || PERL=perl
[ -n "$CURL" ] || CURL=curl
[ -n "$GERRUSER" ] || GERRUSER=stargrave
[ -n "$GERRPASS" ] || GERRPASS=password
[ -n "$GERRADDR" ] || GERRADDR=http://gerrit.lan

change=$1
revision=$2

usage()
{
    echo Usage: $0 CHANGE REVISION
    exit 1
}

[ -n "$change" ] || usage
[ -n "$revision" ] || usage

$CURL --silent --user $GERRUSER:$GERRPASS \
    $GERRADDR/changes/$change/revisions/$revision/comments |
    $PERL -MEncode -MJSON -e '
<STDIN>; # Skip first Gerrit malformed JSON line
my @ser = <STDIN>;
my $deser = decode_json join "", @ser;
foreach my $f (keys %{$deser}) {
    foreach my $comment (@{$deser->{$f}}) {
        print "-----BEGIN R$comment->{id} $f";
        print " $comment->{range}->{start_line}";
        print " $comment->{range}->{end_line}-----\n";
        print "$comment->{author}->{name}:\n";
        my $m = encode_utf8 $comment->{message};
        $m =~ s/\\n/\n/g;
        print "$m\n-----END-----\n\n";
    };
};
'
