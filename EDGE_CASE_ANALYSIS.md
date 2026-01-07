# Manual Analysis: Edge Case Degeneracy at pj=1, qj=1

## Understanding getCorners Behavior

From `getCorners.m`, the logic is:

```matlab
if (pj < kLength)
    pP = p + (kVals(pj+1) - kVals(pj))/2;
else
    pP = p;  % At max index, right edge = p
end

if (pj > 1)
    pM = p - (p - kVals(pj-1))/2;
else
    pM = p;  % At index 1, left edge = p
end
```

Same logic for q coordinates.

## Case Analysis

### Case 1: Interior Cell (pj=50, qj=50, typical case)

For a grid point at `p = kVals(50)`:
- `pM = p - (p - kVals(49))/2` = midpoint between kVals(49) and kVals(50)
- `pP = p + (kVals(51) - p)/2` = midpoint between kVals(50) and kVals(51)

Cell extends halfway to each neighbor. **Width = (p - kVals(49))/2 + (kVals(51) - p)/2**

This is **NOT uniform** for log-spaced grids, but it's non-degenerate.

### Case 2: Bottom-Left Corner (pj=1, qj=1)

For the first grid point `p = q = kVals(1)`:
- `pM = p` (because pj=1, doesn't satisfy pj>1)
- `pP = p + (kVals(2) - kVals(1))/2`
- `qM = q` (because qj=1)
- `qP = q + (kVals(2) - kVals(1))/2`

**Cell bounds**: `[p, p + Δ/2] × [q, q + Δ/2]` where `Δ = kVals(2) - kVals(1)`

**Width**: `(kVals(2) - kVals(1))/2` ✓ Non-zero
**Height**: `(kVals(2) - kVals(1))/2` ✓ Non-zero
**Area**: `[(kVals(2) - kVals(1))/2]²` ✓ Non-degenerate!

**Conclusion**: The cell is NOT a point. It's a proper rectangle, just half the width and height of an interior cell.

### Case 3: Left Edge (pj=1, qj=50)

- `pM = p = kVals(1)`
- `pP = p + (kVals(2) - kVals(1))/2`
- `qM = q - (q - kVals(49))/2` (normal interior logic)
- `qP = q + (kVals(51) - q)/2` (normal interior logic)

**Cell**: Half width in p-direction, full width in q-direction.

**Area**: Non-zero ✓

### Case 4: Top-Right Corner (pj=kLength, qj=kLength)

For the last grid point:
- `pM = p - (p - kVals(kLength-1))/2` (normal)
- `pP = p` (because pj=kLength)
- `qM = q - (q - kVals(kLength-1))/2` (normal)
- `qP = q` (because qj=kLength)

**Cell**: `[p - Δ/2, p] × [q - Δ/2, q]` where `Δ = kVals(kLength) - kVals(kLength-1)`

**Area**: Non-zero ✓

## Degeneracy Check: Are any cells zero-area?

**NO!** All boundary cells have non-zero area. The cells are:
- **Interior cells**: Extend halfway to each neighbor in both directions
- **Edge cells**: Extend halfway to one neighbor, stop at grid point on boundary
- **Corner cells**: Stop at grid point on two boundaries

None of these are degenerate in the sense of zero area.

## BUT: There's a Subtle Issue

### The Cell Center Location

The **cell center** (p, q) is:
- **Interior cells**: At the geometric center of the cell ✓
- **Edge cells**: NOT at the geometric center! The cell is asymmetric.
- **Corner cells**: At the corner, not the center!

### Example: pj=1, qj=1

Cell bounds: `[p, p+Δ/2] × [q, q+Δ/2]`
Cell center (used in logic): `(p, q)`
Geometric centroid: `(p+Δ/4, q+Δ/4)`

**The "center" is actually at the bottom-left corner of the cell!**

### Impact on Cutting Function Logic

The cutting functions check:
```matlab
centerSign = q - p - k;  % For boundary q = k + p
```

This evaluates the sign at `(p, q)`, but for boundary cells, this point is at the EDGE of the cell, not the center.

**Potential Issue**:
- If the boundary line passes exactly through (p, q), we have `centerSign = 0`
- The logic `c1s * centerSign > 0` might fail or give unexpected results
- Vertices might be included/excluded incorrectly

### Concrete Example

Suppose:
- `pj=1, qj=1, kj=1` (corner cell at smallest k)
- `k = 0.01, p = 0.01, q = 0.01`
- Cell: `[0.01, 0.015] × [0.01, 0.015]` (assuming kVals(2) = 0.02)

Boundary line: `q = k + p = 0.01 + p`

At the cell "center" (p,q) = (0.01, 0.01):
- `centerSign = q - p - k = 0.01 - 0.01 - 0.01 = -0.01` (BELOW boundary)

At the actual corners:
- Corner 1 (pM, qP) = (0.01, 0.015): sign = 0.015 - 0.01 - 0.01 = -0.005 (BELOW)
- Corner 2 (pP, qP) = (0.015, 0.015): sign = 0.015 - 0.015 - 0.01 = -0.01 (BELOW)
- Corner 3 (pP, qM) = (0.015, 0.01): sign = 0.01 - 0.015 - 0.01 = -0.015 (BELOW)
- Corner 4 (pM, qM) = (0.01, 0.01): sign = 0.01 - 0.01 - 0.01 = -0.01 (BELOW)

All corners below the boundary → no cut → correct behavior ✓

Let me try a case where the boundary DOES cut the cell...

Suppose k = 0.025 (larger), same cell `[0.01, 0.015] × [0.01, 0.015]`:

Boundary: `q = 0.025 + p`

At corners:
- Corner 1 (0.01, 0.015): sign = 0.015 - 0.01 - 0.025 = -0.02 (BELOW)
- Corner 2 (0.015, 0.015): sign = 0.015 - 0.015 - 0.025 = -0.025 (BELOW)
- Corner 3 (0.015, 0.01): sign = 0.01 - 0.015 - 0.025 = -0.03 (BELOW)
- Corner 4 (0.01, 0.01): sign = 0.01 - 0.01 - 0.025 = -0.025 (BELOW)

All below → no cut. Still correct.

Actually, let's try k = 0.008 (smaller than p,q):

Boundary: `q = 0.008 + p`

At corners:
- Corner 1 (0.01, 0.015): sign = 0.015 - 0.01 - 0.008 = -0.003 (BELOW)
- Corner 2 (0.015, 0.015): sign = 0.015 - 0.015 - 0.008 = -0.008 (BELOW)
- Corner 3 (0.015, 0.01): sign = 0.01 - 0.015 - 0.008 = -0.013 (BELOW)
- Corner 4 (0.01, 0.01): sign = 0.01 - 0.01 - 0.008 = -0.008 (BELOW)

Still all below. Hmm.

Actually, for the boundary `q = k + p` to cut this cell `[0.01, 0.015] × [0.01, 0.015]`, we need:
- At some point in the cell, q > k + p
- At some point in the cell, q < k + p

The cell has:
- Min value: q = 0.01, p = 0.01 → q - p = 0
- Max value: q = 0.015, p = 0.015 → q - p = 0

So `q - p = 0` throughout this cell! (It's on the diagonal)

For a cut: we need `q - p - k` to change sign, which requires `k ∈ (0, 0)` - impossible!

So this particular cell (at pj=qj=1 on the diagonal) is NEVER cut by the `q = k + p` boundary for any k > 0.

## Conclusion: No Degeneracy Issue at Boundaries

The edge cases at `pj=1` or `qj=1` do NOT cause degeneracy problems:
1. Cells have non-zero area ✓
2. The "center" being at the edge of the cell doesn't break the logic ✓
3. The cutting functions should work correctly ✓

**The errors must come from somewhere else.**

## Remaining Suspects

1. **Numerical precision**: Floating-point errors in intersection calculations or polyarea
2. **Vertex ordering bugs**: Logic error in conditional vertex addition
3. **Sign convention confusion**: The double-conversion `A_rectangle - (A_rectangle - cut)`
4. **Rare multi-cut cases**: Even if rare, they might still cause most of the errors
5. **centroidOfEdgeCell differences**: Different numerical approach (coordinate translation, etc.)

The diagnostic script should reveal which of these is the actual culprit.
