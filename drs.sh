#!/bin/bash

# tnu drs access $1 2> /dev/null > $2

if [ $1 == 'drs://dg.4503:dg.4503/e5ea45ea-e8b2-41f0-b9d9-4d538829da17' ]
then
    echo 'http://genome.ucsc.edu/goldenPath/help/examples/cramExample.cram' > $2

elif [ $1 == 'drs://dg.4503:dg.4503/fa640b0e-9779-452f-99a6-16d833d15bd0' ]
then
    echo 'http://genome.ucsc.edu/goldenPath/help/examples/cramExample.cram.crai' > $2

else
    echo $1 > $2
fi
