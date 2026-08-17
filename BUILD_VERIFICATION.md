# Build Verification

## Verify the artifacts

After building:

```
OUT_DIR="$PWD/out" bash scripts/verify/dtb.sh
OUT_DIR="$PWD/out" bash scripts/verify/binman.sh
```

## Check reproducibility

Two isolated builds, hard-fail on hash mismatch:

```
bash scripts/verify/reproducibility.sh
```