#!/usr/bin/env bash
# compile the genome browser CGIs
cd /tmp/kent/src
export COPT="-ggdb"
make -j4 libs

# now make alpha, which by default builds the CGIs into
# /usr/local/apache/cgi-bin/
# Since docker is doing all of this as root we'll be
# good to go
cd hg
make -j4 alpha
