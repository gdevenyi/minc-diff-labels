#!/bin/bash

set -euo pipefail
set -x

tmpdir=$(mktemp -d)

old=$1
new=$2
output=$3

oldlabels=$(print_all_labels $old | cut -d " " -f 2)
newlabels=$(print_all_labels $new | cut -d " " -f 2)
combinedlabels=$(echo ${oldlabels} ${newlabels} | tr ' ' '\n' | sort | uniq)

for label in ${oldlabels}
do
    minclookup -discrete -lut_string "$label 1" $old ${tmpdir}/${label}_old.mnc
done

for label in ${newlabels}; do
    minclookup -discrete -lut_string "$label 1" $new ${tmpdir}/${label}_new.mnc
done

changedlabels=""

for label in ${combinedlabels}; do
    if [[ ! -e ${tmpdir}/${label}_old.mnc ]]; then
        minccalc -expression 'A[0]?0:0' -byte -signed ${tmpdir}/${label}_new.mnc ${tmpdir}/${label}_old.mnc
    elif [[ ! -e ${tmpdir}/${label}_new.mnc ]]; then
        minccalc -expression 'A[0]?0:0' -byte -signed ${tmpdir}/${label}_old.mnc ${tmpdir}/${label}_new.mnc
    fi
            
    minccalc -labels -signed -byte -expression 'A[0] - A[1]' ${tmpdir}/${label}_new.mnc ${tmpdir}/${label}_old.mnc ${tmpdir}/${label}_diff.mnc
    if [[ ! (( $(mincstats -quiet -sum2 ${tmpdir}/${label}_diff.mnc) >  0)) ]]; then
        rm ${tmpdir}/${label}_diff.mnc
    else
        changedlabels+="${label} "
    fi
done



mincconcat -valid_range -1 1 -signed -byte -concat_dimension time -coordlist "$(echo ${changedlabels} | tr ' ' '\n' | paste -s -d",")" $(for label in ${changedlabels}; do echo -n "${tmpdir}/${label}_diff.mnc "; done ) ${output}


rm -rf ${tmpdir}
