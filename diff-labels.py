#!/usr/bin/env python3
"""Compute a per-label diff between two label volumes.

Format-generic (NIfTI/NRRD/MINC, inferred from extension) reimplementation of
diff-labels.sh built on SimpleITK. The diff is a signed 4D stack: one frame per
changed label, voxels valued {-L, 0, +L} where +L = added voxel, -L = removed
voxel. Each frame is self-identifying (label = max|nonzero|; sign = add/remove).

The 4D diff cannot be written as MINC: SimpleITK's MINC IO crashes on 4D writes.
Use a .nii.gz or .nrrd extension for the diff. Inputs (and the patched output of
patch-labels.py) may still be any format, including .mnc.
"""

import argparse
import os
import sys

import numpy as np
import SimpleITK as sitk


def read_labels(path):
    """Read a label volume; return (sitk image, integer numpy array)."""
    img = sitk.ReadImage(path)
    arr = np.rint(sitk.GetArrayFromImage(img)).astype(np.int64)
    return img, arr


def main():
    parser = argparse.ArgumentParser(
        description="Compute a per-label diff between two label volumes.")
    parser.add_argument("old", help="original label volume")
    parser.add_argument("new", help="new label volume to diff against old")
    parser.add_argument(
        "output",
        help="output diff volume (signed 4D per-label stack; .nii.gz/.nrrd, not .mnc)")
    args = parser.parse_args()

    for p in (args.old, args.new):
        if not os.path.exists(p):
            sys.exit(f"Error: input '{p}' not found")

    # 4D MINC writes crash in SimpleITK; refuse up front rather than core-dump.
    if args.output.lower().endswith((".mnc", ".mnc2")):
        sys.exit(
            "Error: the 4D diff cannot be written as MINC (SimpleITK MINC IO "
            "does not support 4D). Use .nii.gz or .nrrd for the diff.")

    old_img, old = read_labels(args.old)
    new_img, new = read_labels(args.new)

    if old.shape != new.shape:
        sys.exit(f"Error: volume sizes differ: {old.shape} vs {new.shape}")

    labels = sorted((set(np.unique(old)) | set(np.unique(new))) - {0})

    # Signed type sized to the label values (fixes the old -byte overflow at L>127).
    max_label = max(labels) if labels else 0
    dtype = np.int16 if max_label <= np.iinfo(np.int16).max else np.int32

    frames = []
    changed_labels = []
    for L in labels:
        frame = ((new == L).astype(np.int64) - (old == L).astype(np.int64)) * L
        if not np.any(frame):
            continue
        changed_labels.append(int(L))
        fim = sitk.GetImageFromArray(frame.astype(dtype))
        fim.CopyInformation(old_img)  # spatial spacing/origin/direction
        frames.append(fim)

    if not frames:
        print(f"No label differences between {args.old} and {args.new}.",
              file=sys.stderr)
        return

    diff = sitk.JoinSeries(frames)
    sitk.WriteImage(diff, args.output)
    print(f"Wrote {len(changed_labels)} changed label(s) {changed_labels} to "
          f"{args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
