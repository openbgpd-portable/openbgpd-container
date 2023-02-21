#!/bin/sh
#
# Copyright (c) 2020-2023 Robert Scheck <robert@fedoraproject.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

set -e
[ -n "${DEBUG}" ] && set -x

# Catch container interruption signals to remove hint file for health script
cleanup() {
  rm -f /tmp/bgpd.daemon-expected
}
trap cleanup INT TERM

# Check if first argument is a flag, but only works if all arguments require
# a hyphenated flag: -v; -SL; -f arg; etc. will work, but not arg1 arg2
if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ]; then
  set -- bgpd "$@"
fi

# Check for the expected command
if [ "$1" = 'bgpd' ]; then
  [ "$2" != '-V' ] && touch /tmp/bgpd.daemon-expected
fi

# Default to run whatever the user wanted, e.g. "sh"
exec "$@"
