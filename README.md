Idea for diffing label sets in MINC.
--------------------------------------------

Use the extra dimensionality to store labels as a "time" dimension. This could be an arbitrary dimension name, but time allows viewing in Display/register.


## How this tool works:

Steps to compute a diff:

1. Use minclookup to split up two label sets to diff. One file per label, all values 1
2. Use minccalc to do "new - old"
- 0 no change
- 1 added voxel
- -1 removed voxel

This creates a per-voxel index of changes to label set.

3. Stack these labels in a time dimension using mincconcat, use the label numbers as the time coordinates

Steps to apply a diff:

1. Split input label set into one file per label.
2. Split out time dimension on diff into per file diffs
3. Apply diff to label file using minccalc, multiply by label value
4. Merge label files back into a single file
