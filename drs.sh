#!/bin/bash -e

if [ $# != 1 ] ;then
  echo "wrong # args $0 inurl" >&2
  exit 1
fi

tnu drs access $1
