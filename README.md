Diffing label sets, format-generic.
--------------------------------------------

Compute and apply per-label diffs between segmentation/atlas volumes. Built on
[SimpleITK](https://simpleitk.org), so the same code works on any ITK-supported
format — NIfTI (`.nii`/`.nii.gz`), NRRD (`.nrrd`), and MINC (`.mnc`) — with the
format inferred from each file's extension.

The diff is stored as a signed 4D stack: one frame per changed label, with voxels
valued `{-L, 0, +L}` where `+L` marks an added voxel and `-L` a removed voxel for
label `L`. Each frame is self-identifying, so no sidecar file is needed.

## Requirements

- Python ≥ 3.10 with [`uv`](https://docs.astral.sh/uv/)
- `simpleitk`, `numpy` (installed into a local venv by `uv`)

```sh
uv venv
uv pip install simpleitk numpy   # or: uv pip install -e .
```

## Usage

Create a diff (the diff must be `.nii.gz` or `.nrrd` — see the MINC note below):
```sh
uv run ./diff-labels.py old.mnc new.mnc diff.nii.gz
```
Identical inputs produce no output and exit cleanly with a message.

Apply a diff (output may be any format, including `.mnc`):
```sh
uv run ./patch-labels.py old.mnc diff.nii.gz new.mnc
```

Inputs may mix formats; conversion is implicit:
```sh
uv run ./diff-labels.py old.nii.gz new.nrrd diff.nrrd
uv run ./patch-labels.py old.nii.gz diff.nrrd recon.mnc
```

## MINC limitation

SimpleITK's MINC ImageIO crashes when *writing* 4D volumes, so the 4D **diff**
cannot be a `.mnc` file — `diff-labels.py` refuses a `.mnc` diff output with a
clear error. This only affects the diff container: label **inputs** and the
patched **output** can be `.mnc`. Use `.nii.gz` or `.nrrd` for the diff.

## How it works

Diff (`diff-labels.py`):
1. Read both label volumes; take the union of their label values (background `0`
   excluded — its diff is redundant with the real changes).
2. For each label `L`, compute `(new==L) - (old==L)` and scale by `L`, giving
   voxels in `{-L, 0, +L}` (`+L` added, `-L` removed).
3. Keep only labels that changed and stack them along a 4th dimension. The signed
   integer type is sized to the label values (no overflow for labels > 127).

Patch (`patch-labels.py`):
1. Start from the original volume.
2. For each diff frame, recover its label `L = max|nonzero|`; set added voxels
   (`+L`) to `L`, and clear removed voxels (`-L`) where the voxel currently holds
   `L`. Unchanged labels and background carry through untouched.

## Legacy scripts

The original minc-toolkit bash implementation is kept as `diff-labels.sh.legacy`
and `patch-labels.sh.legacy` (minc-toolkit-v2 required). The visualization helper
`minc-diff-labels-visualize.sh` also remains but is **MINC-only and legacy**: it
reads the old MINC time-coordinate diff format and does not understand the
SimpleITK 4D diff produced here.
