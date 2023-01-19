#!/bin/bash -e

# use with "track type=bigBed name=fred bigDataUrl=drs://wtf.edu/hg38/primers.bb"

if [ $# != 2 ] ;then
  echo "wrong # args $0 inurl outfile" >&2
  exit 1
fi
URL=https://hgwdev.gi.ucsc.edu/~markd/gencode/lrgasp/experimental-eval/hub/hg38/primers.bb
echo $URL >$2
