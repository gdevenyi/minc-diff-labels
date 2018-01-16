Idea for diffing label sets in MINC.

Use the extra dimensionality to store labels as a "time" dimension.

Use minclookup to split up two label sets to diff. One file per label, all values 1

Then use minccalc to do "new - old"
- 0 no change
- 1 added voxel
- -1 removed voxel

This creates a per-voxel index of changes to label set.

This type of diff can also be applied against another label through the splitting and minccalc feature.

Extraction from diff must happen with combination of mincreshape and mincinfo -varvalues time diff.mnc
