#!/bin/bash
#Generate auto-scaled MaGeT QC image
#TODO
#-option for label on-off slices
#-option for number of slices
#-option for image size
#-clobber check

set -euo pipefail
#set -x

image=$1
labels=$2
output=$3
tmpdir=$(mktemp -d)

patchlabels=$(mincinfo -varvalues time ${labels})

i=0
for label in ${patchlabels}; do
    echo "mincreshape -valid_range -1 1 ${labels} ${tmpdir}/${label}_patch.mnc -dimrange time=${i} -signed -byte && \
         minclookup -byte -unsigned -labels -discrete -lut_string \"-1 2; 1 1\" ${tmpdir}/${label}_patch.mnc ${tmpdir}/${label}_patch_fix.mnc"
    # Generate an empty file if not present in existing label set so we can patch it
    ((i++)) || true
done | parallel -j $(nproc)



# Generate a bounding box
mincmath -or ${tmpdir}/*_patch_fix.mnc ${tmpdir}/label_flatten.mnc
mincresample -unsigned -int -keep -near -labels $(mincbbox -mincresample ${tmpdir}/label_flatten.mnc | grep -v Reading) \
    ${tmpdir}/label_flatten.mnc ${tmpdir}/label-crop.mnc
minccalc -expression "1" ${tmpdir}/label-crop.mnc ${tmpdir}/bounding.mnc

# Labelled layers
for label in ${patchlabels}; do
echo """
create_verify_image -transpose  -range_floor 0 ${tmpdir}/$(basename ${image} .mnc)_t_${label}.mpc \
    -width 3840 -height 1600 -autocols 10 -autocol_planes t \
    -bounding_volume ${tmpdir}/bounding.mnc \
    -row ${image} color:gray \
    volume_overlay:${tmpdir}/${label}_patch_fix.mnc:0.7:2:blue,1:red \
    title:\"Label ${label}\" \
    -norepeattitle


create_verify_image -transpose  -range_floor 0 ${tmpdir}/$(basename ${image} .mnc)_s_${label}.mpc \
    -width 3840 -height 1600 -autocols 10 -autocol_planes s \
    -bounding_volume ${tmpdir}/bounding.mnc \
    -row ${image} color:gray \
    volume_overlay:${tmpdir}/${label}_patch_fix.mnc:0.7:2:blue,1:red \
    title:\"Label ${label}\" \
    -norepeattitle

create_verify_image -transpose  -range_floor 0 ${tmpdir}/$(basename ${image} .mnc)_c_${label}.mpc \
    -width 3840 -height 1600 -autocols 10 -autocol_planes c \
    -bounding_volume ${tmpdir}/bounding.mnc \
    -row ${image} color:gray \
    volume_overlay:${tmpdir}/${label}_patch_fix.mnc:0.7:2:blue,1:red \
    title:\"Label ${label}\" \
    -norepeattitle
"""
done | parallel -j $(nproc)

convert -background black -strip -interlace Plane -sampling-factor 4:2:0 -quality "95%"  \
    +append -trim \
    $(for label in ${patchlabels}; do echo ${tmpdir}/$(basename ${image} .mnc)_t_${label}.mpc; done) \
    ${output}_t.jpg

convert -background black -strip -interlace Plane -sampling-factor 4:2:0 -quality "95%"  \
    +append -trim \
    $(for label in ${patchlabels}; do echo ${tmpdir}/$(basename ${image} .mnc)_s_${label}.mpc; done) \
    ${output}_s.jpg

convert -background black -strip -interlace Plane -sampling-factor 4:2:0 -quality "95%"  \
    +append -trim \
    $(for label in ${patchlabels}; do echo ${tmpdir}/$(basename ${image} .mnc)_c_${label}.mpc; done) \
    ${output}_c.jpg

rm -rf ${tmpdir}
