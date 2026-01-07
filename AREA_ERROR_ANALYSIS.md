# Area Error Analysis for midpoint2dShoelace

## Overview
The `midpoint2dShoelace` function computes areas of cells in the p-q plane that are cut by three boundary lines:
- q = p + k (upper boundary)
- q = p - k (lower right boundary)
- q = k - p (lower left boundary)

The function uses TWO independent methods to calculate areas and compares them for consistency. Errors occur when these two methods disagree.

## Two Area Calculation Methods

### Method 1: Subtraction Method (`areas` variable)
**Location**: Lines 130 and 139 in midpoint2dShoelace.m

This method:
1. Starts with the full rectangular cell area: `A_rectangle = (pP-pM)*(qP-qM)`
2. Calls cutting functions for each boundary line that intersects the cell
3. Combines cut areas based on whether the cell center is inside or outside the triad

**For cells INSIDE the triad** (line 130):
```matlab
areas(pj,qj,kj) = A_rectangle - flag1*dAcutByKPlusP - flag2*dAcutByKMinusP - flag3*dAcutByPMinusK;
```

**For cells OUTSIDE the triad** (line 139):
```matlab
areas(pj,qj,kj) = flag1*dAcutByKPlusP + flag2*dAcutByKMinusP + flag3*dAcutByPMinusK;
```

### Method 2: Direct Shoelace Method (`areas2` variable)
**Location**: Lines 56, 224 via `centroidOfEdgeCell` function

This method:
1. Directly constructs the polygon vertices by finding all intersections of domain boundaries with cell edges
2. Uses the shoelace formula to compute area directly
3. Does not rely on combining multiple cut areas

**Error Detection**: Line 149-157 checks if `|areas2 - areas| > 1e-4`

## Root Causes of Errors

### 1. **MAIN ISSUE: Overlapping Cuts Not Handled Properly**
**Location**: Lines 130 and 139

When a cell is cut by multiple boundaries, the cutting areas can **overlap**. The current code assumes independence and simply adds/subtracts:

```
Total_Area = A_rectangle - Cut1 - Cut2 - Cut3
```

However, if Cut1 and Cut2 overlap near a corner, this double-counts the overlapping region!

**Example Scenario**:
- Cell at very small k values (k ≈ 0.01) with p,q ≈ 100
- All three lines might pass through the cell
- The cut regions overlap significantly
- Simple subtraction gives wrong answer

**Evidence**: Errors are more likely when `flag1 + flag2 + flag3 > 1` (multiple cuts active)

### 2. **Logic Issue: Redundant Cutting Function Calls**
**Location**: Lines 72-128

The nested loops over corners can trigger the cutting function call multiple times:
```matlab
for i = 1:2
    for j = 1:2
        sign = q0-p0-k;
        if (centerSign*sign <= 0)
            dAcutByKPlusP = cutBykPlusP(p,q,k,pM,pP,qM,qP);  % Called up to 4 times!
            dAcutByKPlusP = A_rectangle-dAcutByKPlusP;
            flag1 = 1;
        end
    end
end
```

While only the last call matters (previous values are overwritten), this is inefficient. More importantly, the logic should only call the cutting function ONCE per boundary, not once per corner.

### 3. **Boundary Condition Issues with Logarithmic Spacing**
**Location**: Throughout, especially at extreme k values

With `kVals` logarithmically spaced from 0.01 to 10^5:
- Adjacent cells have vastly different sizes
- At small k (k ≈ 0.01): cells are tiny, boundaries are close together
- At large k (k ≈ 10^5): cells are huge, boundaries are far apart

**Numerical precision problems**:
- Very small areas (< 1e-10) trigger warning at line 57-59
- Cut area calculations lose precision when cell size << k or cell size >> k
- The threshold 1e-4 (line 149) may be too strict for large k, too lenient for small k

### 4. **Sign Convention Confusion**
**Location**: Lines 79-127

Each cutting function "returns area that includes center point" (see comments in cutBykPlusP.m:3). The code then does:
```matlab
dAcutByKPlusP = A_rectangle - dAcutByKPlusP;
```

This converts to "area that does NOT include center point". However:
- When center is INSIDE triad: we subtract these areas (line 130) ✓ Correct
- When center is OUTSIDE triad: we add these areas (line 139) ✓ Correct

The logic appears correct here, but the double-conversion is confusing and error-prone.

## Where Errors Are Most Likely

### High-Risk Regions:

1. **Multi-cut cells near the origin** (small p, q, k)
   - All three boundaries converge near (0,0,0)
   - Multiple cuts overlap significantly
   - Example: k=0.01, p=0.015, q=0.02

2. **Boundary cells** (pj=1, qj=1, or at max index)
   - Cell is not fully rectangular (pM=p or pP=p)
   - Edge case logic in getCorners (lines 3-24)
   - Cutting functions may not handle correctly

3. **Cells where center is just outside triad but corner is inside**
   - `triadCondition(q,p,k) = 0` but `anyCornerInside > 0`
   - Uses "outside" formula (line 139) which adds cut areas
   - More susceptible to overlap errors

4. **Large k values with small p,q** (k ≈ 10^4, p,q ≈ 0.01-1)
   - Boundaries q=k±p are nearly horizontal
   - Small p,q cells are tiny compared to k
   - Numerical precision issues in cut calculations

## Detection Strategy

The error check at line 149-157 already detects discrepancies. To diagnose further:

1. **Track which flags are active** when errors occur
   - Hypothesis: errors increase with number of active cuts
   - Check: are errors more common when flag1+flag2+flag3 = 2 or 3?

2. **Check k value distribution** of errors
   - Hypothesis: errors at extreme k values (very small or very large)
   - Check: plot error vs. k on log scale

3. **Examine outsideCutCell cases** specifically
   - Line 155 prints outsideCutCell flag
   - Hypothesis: "outside but piece inside" cases are most error-prone

4. **Compare polygon vertex count** from centroidOfEdgeCell
   - Complex polygons (many vertices) harder to compute correctly
   - Add diagnostic to count vertices

## Recommendations for Fixes

### Short-term (Diagnostic):
1. Add more detailed error reporting:
   - Print k, p, q values when error occurs
   - Print which flags are active
   - Print vertex coordinates from centroidOfEdgeCell

### Medium-term (Fix):
2. **Trust the shoelace method** (`areas2`):
   - It directly computes the correct polygon area
   - Replace `areas` with `areas2` throughout
   - Simplifies code significantly

3. **If keeping subtraction method**, fix overlaps:
   - Don't assume cuts are independent
   - When multiple flags active, use intersection logic
   - Or: compute union of cuts properly

### Long-term (Redesign):
4. Consider adaptive tolerance:
   - Current threshold 1e-4 is absolute
   - Use relative error: `|areas2-areas|/max(areas2,areas) > 1e-6`
   - Scale threshold with cell size

5. Simplify cutting logic:
   - Remove nested loops (lines 72-128)
   - Check once if boundary cuts cell
   - Call cutting function only if needed

## Summary

**Primary Error Source**: When multiple boundary lines cut a cell, the current subtraction method (Method 1) assumes the cut areas are independent. In reality, they can overlap, leading to double-counting.

**Secondary Issues**: Numerical precision at extreme k values, inefficient redundant cutting function calls, and boundary condition handling.

**Verification**: Method 2 (shoelace/centroidOfEdgeCell) is more reliable and should be considered the "ground truth" for comparison.
