#!/usr/bin/env python3
"""Apply a per-label diff onto an original label volume.

Format-generic (NIfTI/NRRD/MINC, inferred from extension) reimplementation of
patch-labels.sh built on SimpleITK. Reads the signed 4D diff produced by
diff-labels.py and reconstructs the new label volume. The patched output may be
any format, including .mnc.
"""

import argparse
import os
import sys

import numpy as np
import SimpleITK as sitk


def main():
    parser = argparse.ArgumentParser(
        description="Apply a per-label diff onto an original label volume.")
    parser.add_argument("old", help="original label volume")
    parser.add_argument("patch", help="diff volume from diff-labels.py")
    parser.add_argument("output", help="output reconstructed label volume")
    args = parser.parse_args()

    for p in (args.old, args.patch):
        if not os.path.exists(p):
            sys.exit(f"Error: input '{p}' not found")

    old_img = sitk.ReadImage(args.old)
    old = sitk.GetArrayFromImage(old_img)
    old_dtype = old.dtype

    diff = sitk.GetArrayFromImage(sitk.ReadImage(args.patch))
    # Diff is 4D (t,z,y,x); tolerate a bare 3D single-frame diff too.
    if diff.ndim == 3:
        diff = diff[np.newaxis, ...]
    if diff.shape[1:] != old.shape:
        sys.exit(f"Error: diff spatial size {diff.shape[1:]} does not match "
                 f"old {old.shape}")

    result = old.astype(np.int64).copy()
    for frame in diff:
        if not np.any(frame):
            continue
        L = int(np.abs(frame).max())  # frame's label
        s = np.sign(frame)            # +1 added, -1 removed
        result[s == 1] = L
        # Remove L only where the voxel currently holds L (order-independent;
        # a removal with no matching voxel is a safe no-op).
        result[(s == -1) & (result == L)] = 0

    out = sitk.GetImageFromArray(result.astype(old_dtype))
    out.CopyInformation(old_img)
    sitk.WriteImage(out, args.output)
    print(f"Wrote {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
