#!/bin/bash

set -euo pipefail
set -x

tmpdir=$(mktemp -d)

old=$1
new=$2
output=$3

labels=$(print_all_labels $old | cut -d " " -f 2)
for label in ${labels}
do
    minclookup -discrete -lut_string "$label 1" $old ${tmpdir}/${label}_old.mnc
    minclookup -discrete -lut_string "$label 1" $new ${tmpdir}/${label}_new.mnc
    minccalc -labels -signed -byte -expression 'A[0] - A[1]' ${tmpdir}/${label}_new.mnc ${tmpdir}/${label}_old.mnc ${tmpdir}/${label}_diff.mnc
    rm ${tmpdir}/${label}_old.mnc ${tmpdir}/${label}_new.mnc
done


mincconcat -valid_range "-1 1" -signed -byte -concat_dimension time -coordlist "$(echo ${labels} | tr ' ' '\n' | paste -s -d",")" $(for label in $labels; do echo -n "${tmpdir}/${label}_diff.mnc "; done ) ${output}


rm -rf ${tmpdir}
