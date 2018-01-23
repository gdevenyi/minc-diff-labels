#!/bin/bash

set -euo pipefail
set -x

tmpdir=$(mktemp -d)

old=$1
patch=$2
output=$3

labels=$(print_all_labels $old | cut -d " " -f 2)
patchlabels=$(mincinfo -varvalues time $patch)
combinedlabels=$(echo ${labels} ${patchlabels} | tr ' ' '\n' | sort | uniq)

for label in ${labels}; do
    minclookup -discrete -lut_string "$label 1" ${old} ${tmpdir}/${label}_old.mnc
done

i=1
for patchlabel in ${patchlabels}; do
    mincreshape -valid_range -1 1 ${patch} ${tmpdir}/${patchlabel}_patch.mnc -dimrange time=${i} -signed -byte
    #Generate an empty file if not present in existing label set so we can patch it
    if [[ ! -e ${tmpdir}/${patchlabel}_old.mnc ]]; then
    minccalc -expression 'A[0]?0:0' -byte -signed ${tmpdir}/${patchlabel}_patch.mnc ${tmpdir}/${patchlabel}_old.mnc
    fi
    ((i++))
done

for label in ${combinedlabels}; do
    minccalc -labels -unsigned -byte -expression "(A[0]+A[1])*${label}" ${tmpdir}/${label}_old.mnc ${tmpdir}/${label}_patch.mnc ${tmpdir}/${label}_new.mnc
done

mincmath -labels -unsigned -byte -add ${tmpdir}/*_new.mnc ${output}


rm -rf ${tmpdir}
