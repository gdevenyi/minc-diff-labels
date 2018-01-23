#!/bin/bash

set -euo pipefail
set -x

tmpdir=$(mktemp -d)

old=$1
patch=$2
output=$3

oldlabels=$(print_all_labels ${old} | cut -d " " -f 2)
patchlabels=$(mincinfo -varvalues time ${patch})
combinedlabels=$(echo ${oldlabels} ${patchlabels} | tr ' ' '\n' | sort | uniq)

#Split up original label file
for label in ${oldlabels}; do
    minclookup -discrete -lut_string "$label 1" ${old} ${tmpdir}/${label}_old.mnc
done

#Split up patch set
i=0
for label in ${patchlabels}; do
    mincreshape -valid_range -1 1 ${patch} ${tmpdir}/${label}_patch.mnc -dimrange time=${i} -signed -byte
    #Generate an empty file if not present in existing label set so we can patch it
    ((i++)) || true
done

#Apply patch to labels, in the case of missing label or patch, skip patching
for label in ${combinedlabels}; do
    if [[ ! -e ${tmpdir}/${label}_old.mnc ]]; then
        if [[ $(mincstats -min -quiet ${tmpdir}/${label}_patch.mnc) == "-1" ]]; then
            echo "Warning, patch ${label} deletes voxels but no original label exists! Ignoring negative patches!"
        fi
        minccalc -labels -unsigned -byte -expression "A[0]>0?(A[0]*${label}):0" ${tmpdir}/${label}_patch.mnc ${tmpdir}/${label}_new.mnc
    elif [[ ! -e ${tmpdir}/${label}_patch.mnc ]]; then
        minccalc -labels -unsigned -byte -expression "A[0]*${label}" ${tmpdir}/${label}_old.mnc ${tmpdir}/${label}_new.mnc
    else
        minccalc -labels -unsigned -byte -expression "(A[0]+A[1])*${label}" ${tmpdir}/${label}_old.mnc ${tmpdir}/${label}_patch.mnc ${tmpdir}/${label}_new.mnc
    fi
done

mincmath -labels -unsigned -byte -add ${tmpdir}/*_new.mnc ${output}


rm -rf ${tmpdir}
