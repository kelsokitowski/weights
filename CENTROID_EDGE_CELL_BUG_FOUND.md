# CRITICAL BUG FOUND in centroidOfEdgeCell.m

## Bug #1: Inconsistent Inequality in Intersection Checks

**Location**: Lines 12, 18, 23 (and similar throughout the function)

```matlab
% Line 12 - checking q = p - k on top edge
if ( (pM<pSolution) && (pSolution<= pP) )  // Uses <=

% Line 18 - checking q = p + k on top edge
if ( (pM<pSolution) && (pSolution< pP) )   // Uses <

% Line 23 - checking q = k - p on top edge
if ( (pM<pSolution) && (pSolution< pP) )   // Uses <
```

**The Problem**:
- The first check uses `pSolution <= pP` (inclusive)
- The other two use `pSolution < pP` (exclusive)

**Impact**:
When an intersection point lands EXACTLY at a cell corner:
- Line 12 will ADD the point (because of <=)
- Lines 18, 23 will NOT add the point (because of <)
- Then line 27-30 adds the corner if it's inside the triad

**Result**:
- If the corner is inside AND line 1 intersects there: DUPLICATE vertex added
- If the corner is inside AND line 2 or 3 intersects there: Correct (corner added once)
- If the corner is outside AND line 1 intersects there: Correct (intersection added once)
- If the corner is outside AND line 2 or 3 intersects there: MISSING vertex!

This inconsistency causes:
- Duplicate vertices → polyarea might return incorrect value
- Missing vertices → polygon is incomplete → area is wrong

## Bug #2: Potential Missing Intersections at Cell Corners

**Example Scenario**:

Cell: [1.0, 2.0] × [1.0, 2.0]
k = 1.5
Boundary line: q = p + k = p + 1.5

At the top-right corner (pP=2.0, qP=2.0):
- Is this corner on the boundary? q = p + k → 2.0 = 2.0 + 1.5? No, 2.0 ≠ 3.5
- So not on this line.

Actually, let me find when corners ARE on boundaries:

**Line q = p - k**: Corner (p0, q0) is on line when q0 = p0 - k → pP = qP + k

**Line q = p + k**: Corner is on line when qP = pP + k

**Line q = k - p**: Corner is on line when qP = k - pP

For logarithmically spaced grids, it's unlikely but POSSIBLE for intersections to land exactly at corners, especially at specific k values.

When this happens, the inconsistent inequality causes errors.

## Bug #3: Incorrect Intersection Formula?

**Line 22-25** (top edge, checking q = k - p):
```matlab
pSolution = k-qP; %bottom left of omega
if ( (pM<pSolution) && (pSolution< pP) )
    x = [x, pSolution];
    y = [y, qP];
end
```

The comment says "bottom left of omega", but this is checking the TOP edge of the cell (y = qP).

The boundary is q = k - p, so at the top edge (q = qP), the intersection is:
- qP = k - p
- p = k - qP ✓

This is correct. The comment is just about which part of the triad domain this represents, not an error.

## Bug #4: Why Errors Increase with k

For large k values:
1. The triad region is larger
2. More cells are partially inside the triad (cut by boundaries)
3. More intersection calculations are performed
4. More opportunities for the inequality bug to trigger
5. Each error contributes to the total area sum

For small k values:
1. Fewer cells involved
2. Fewer intersection calculations
3. Less chance for the bug to manifest

**This explains why error increases with k!**

## Bug #5: The Analytical Formula Discrepancy

The code uses:
```matlab
analytical = 2*k*max(kVals) - 1.5*k^2;
```

But integrating the triad region from 0 to M gives:
```
Area = ∫_0^k 2p dp + ∫_k^M 2k dp = k² + 2k(M-k) = 2kM - k²
```

The formula has `-1.5k²` instead of `-k²`. **This is a 0.5k² discrepancy!**

For k = 100, this is a difference of 5000 in the analytical area!

**Hypothesis**: The formula might be accounting for some boundary effect or using a different integration domain.

**Alternative**: Maybe there's a typo and it should be `-k²`?

## Recommended Diagnostic

1. **Fix the inequality inconsistency**:
   Change ALL intersection checks to use the SAME inequality (either all `<=` or all `<`)

2. **Check for duplicate vertices**:
   Before computing area, check if any adjacent vertices are identical

3. **Verify analytical formula**:
   Numerically integrate the triad region and compare to the formula

4. **Test at specific k values**:
   For k where errors are largest, print out the vertex lists and check for duplicates/missing points

## Proposed Fix

**Option 1**: Use `<` everywhere (exclude right/top boundaries)
- Corners added separately via triadCondition check
- No risk of duplicates

**Option 2**: Use `<=` everywhere (include right/top boundaries)
- Check before adding corner: if already in list, skip
- More robust but slightly slower

**Option 3**: Fix the analytical formula
- If it should be `-k²` instead of `-1.5k²`, change it
- This immediately fixes 50% of the error for large k!

