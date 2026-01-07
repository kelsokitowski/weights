# Critical Issues Found - Action Required

## Summary

You reported 20% error in areas2 (centroidOfEdgeCell method) that increases with k. I've identified **two critical bugs** that likely explain this:

## Bug #1: Inconsistent Inequality in Intersection Detection ⚠️

**Location**: centroidOfEdgeCell.m throughout

**The Problem**:
```matlab
% Line 12 (checking q = p - k intersection on top edge)
if ( (pM<pSolution) && (pSolution<= pP) )  // Uses <=

% Line 18 (checking q = p + k intersection on top edge)
if ( (pM<pSolution) && (pSolution< pP) )   // Uses <

% Line 23 (checking q = k - p intersection on top edge)
if ( (pM<pSolution) && (pSolution< pP) )   // Uses <
```

**Impact**:
- When an intersection point lands exactly at a cell corner (pSolution = pP):
  - Line 12 INCLUDES it (<=)
  - Lines 18, 23 EXCLUDE it (<)
- Then lines 27-30 add the corner if it's inside the triad
- **Result**: Either duplicate vertices OR missing vertices
- Duplicate vertices → polyarea returns wrong area
- Missing vertices → incomplete polygon → wrong area

**Why error increases with k**:
- Large k → more cells cut by boundaries
- More intersection calculations
- More opportunities for this bug to trigger
- Accumulated error in the sum

**Quick Test**:
Add logging before line 163 in centroidOfEdgeCell.m:
```matlab
% Check for duplicate vertices
if length(xVals) > length(unique(xVals))
    fprintf('DUPLICATE vertices detected at k=%.4f, pM=%.4f, qM=%.4f\n', k, pM, qM);
    fprintf('xVals: %s\n', mat2str(xVals));
    fprintf('yVals: %s\n', mat2str(yVals));
end
```

**Fix**:
Change ALL inequality checks to use consistent comparison. Recommend using `<` everywhere:

```matlab
% Change line 12 from:
if ( (pM<pSolution) && (pSolution<= pP) )
% To:
if ( (pM<pSolution) && (pSolution< pP) )
```

Apply same fix to lines 18, 23, 52, 57, 62, 89, 94, 100, 127, 132, 138.

Corners will be added separately via triadCondition checks, avoiding duplicates.

## Bug #2: Analytical Formula Discrepancy ⚠️

**Location**: midpoint2dShoelace.m line 358

**The Problem**:
```matlab
analytical = 2*k*max(kVals) - 1.5*k^2;
```

**Mathematical Derivation**:
For triad region integrated from p=0 to M:
```
Area = ∫_0^k 2p dp + ∫_k^M 2k dp
     = k² + 2k(M-k)
     = 2kM - k²
```

**Your formula has `-1.5k²` instead of `-k²`**

**Discrepancy**: 0.5k²

For k=100: Difference = 5000
For k=1000: Difference = 500,000

**Impact on error**:
If the formula should be `-k²`, then for large k:
- Expected: 2kM - k²
- Actual code: 2kM - 1.5k²
- Ratio: (2kM - 1.5k²)/(2kM - k²)

For k → M:
- Expected: 2M² - M² = M²
- Code: 2M² - 1.5M² = 0.5M²
- Ratio: 0.5 (50% error!)

**However**, you report 20% error, not 50%. This suggests:
1. Either the formula is correct for a different integration domain
2. Or there are two offsetting errors

**Test**:
Try changing line 358 to:
```matlab
analytical = 2*k*max(kVals) - k^2;
```

Run your code and check if errors decrease.

## Additional Investigation Needed

### Check #1: Verify Analytical Formula

Run `investigate_analytical_formula.m` (I created this file) to:
- Numerically integrate the triad region
- Compare to both formula versions
- Identify which is correct

### Check #2: Grid Coverage

The grid cells cover [kVals(1), kVals(end)], not [0, max(kVals)].

If kVals(1) = 0.01, there's a missing region [0, 0.01] × [0, 0.01] that the analytical formula might assume is included.

For the analytical formula to match, it might need to be:
```matlab
analytical = 2*k*(max(kVals)-min(kVals)) - ...
```

Or integrate from kVals(1) instead of 0.

### Check #3: Vertex Count Distribution

Add diagnostic to count vertices in each polygon:
```matlab
numVertices = length(xVals);
if numVertices > 8
    fprintf('WARNING: Polygon has %d vertices (expected ≤8)\n', numVertices);
end
```

If you see counts > 8, it means duplicate vertices are being added.

## Recommended Action Plan

**Step 1**: Fix the inequality inconsistency (Bug #1)
- This is definitely wrong and WILL cause errors
- Change all intersection checks to use `<` instead of mix of `<` and `<=`

**Step 2**: Test the analytical formula (Bug #2)
- Try changing `-1.5k²` to `-k²`
- See if errors decrease

**Step 3**: If errors persist
- Check for duplicate vertices (diagnostic above)
- Verify grid coverage matches analytical assumption
- Check if symmetry copying (line 158) is causing double-counting

**Step 4**: Report back
- Which fix(es) worked?
- What's the remaining error after fixes?
- I can investigate further if needed

## My Prediction

Fixing Bug #1 (inequality inconsistency) will reduce errors significantly, possibly to < 1%.

The analytical formula discrepancy (Bug #2) might explain the rest.

Together, these two bugs likely account for most or all of your 20% error.

