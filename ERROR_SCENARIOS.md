# Specific Error Scenarios in midpoint2dShoelace

This document describes concrete scenarios where area calculation errors occur, with specific examples and geometric explanations.

## Scenario 1: Multiple Overlapping Cuts (Most Critical)

### Geometric Setup
Consider a cell at indices `(pj, qj, kj)` where:
- k = 0.5 (small but not tiny)
- p = 0.6
- q = 0.7

The cell boundaries are approximately:
- pM = 0.55, pP = 0.65
- qM = 0.65, qP = 0.75

### Boundary Lines
The three triad boundaries are:
1. q = k + p  →  q = 0.5 + p  →  q = 1.1 at p=0.6
2. q = k - p  →  q = 0.5 - p  →  q = -0.1 at p=0.6 (below cell)
3. q = p - k  →  q = p - 0.5  →  q = 0.1 at p=0.6 (below cell)

### Cell Center Status
- Center (p,q) = (0.6, 0.7) satisfies:
  - q ≥ k - p: 0.7 ≥ -0.1 ✓
  - q ≤ k + p: 0.7 ≤ 1.1 ✓
  - q ≥ p - k: 0.7 ≥ 0.1 ✓
- **Center is INSIDE the triad**

### Which Boundaries Cut This Cell?
Checking the four corners:

**Corner 1: (pM, qP) = (0.55, 0.75)**
- Line q = k + p: 0.75 vs 1.05 → below line (inside domain)
- Line q = k - p: 0.75 vs -0.05 → above line (inside domain)
- Line q = p - k: 0.75 vs 0.05 → above line (inside domain)

**Corner 2: (pP, qP) = (0.65, 0.75)**
- Line q = k + p: 0.75 vs 1.15 → below line (inside domain)
- Line q = k - p: 0.75 vs -0.15 → above line (inside domain)
- Line q = p - k: 0.75 vs 0.15 → above line (inside domain)

**Corner 3: (pP, qM) = (0.65, 0.65)**
- Line q = k + p: 0.65 vs 1.15 → below line (inside domain)
- Line q = k - p: 0.65 vs -0.15 → above line (inside domain)
- Line q = p - k: 0.65 vs 0.15 → above line (inside domain)

**Corner 4: (pM, qM) = (0.55, 0.65)**
- Line q = k + p: 0.65 vs 1.05 → below line (inside domain)
- Line q = k - p: 0.65 vs -0.05 → above line (inside domain)
- Line q = p - k: 0.65 vs 0.05 → above line (inside domain)

All corners are inside! So none of these boundaries actually cut this cell. **This is not the error case.**

Let me reconsider...

## Scenario 1 (Revised): Edge Cell at Small k

### Geometric Setup
- k = 0.02 (very small)
- p = 0.01 (at lower edge of grid)
- q = 0.015 (between boundaries)

Cell boundaries:
- pM = 0.01, pP = 0.012 (first cell, so pM = p)
- qM = 0.013, qP = 0.017

### Boundary Lines at this k
1. q = k + p  →  q = 0.02 + p  →  q = 0.03 at p=0.01 (above cell)
2. q = k - p  →  q = 0.02 - p  →  q = 0.01 at p=0.01 (below cell)
3. q = p - k  →  q = p - 0.02  →  q = -0.01 at p=0.01 (below cell)

### The Problem
The cell is TINY (0.002 × 0.004 = 0.000008 area). The boundaries q=k-p and q=p-k both pass very close to the cell. Small numerical errors in:
- Finding intersection points
- Computing polygon areas with `polyarea`
- The shoelace formula with small coordinates

can lead to relative errors exceeding the threshold.

## Scenario 2: Outside Cell with Multiple Cuts

### Geometric Setup
- k = 1.0
- p = 2.5
- q = 0.5

Cell boundaries:
- pM = 2.4, pP = 2.6
- qM = 0.48, qP = 0.52

### Cell Center Status
Check triad condition for (p,q) = (2.5, 0.5):
- q ≥ k - p: 0.5 ≥ -1.5 ✓
- q ≤ k + p: 0.5 ≤ 3.5 ✓
- q ≥ p - k: 0.5 ≥ 1.5 ✗

**Center is OUTSIDE the triad** (fails q ≥ p - k)

### Which Boundaries Cut This Cell?

**Line 1: q = k + p = 1 + p**
- At pM=2.4: q=3.4 (far above cell top qP=0.52)
- Doesn't cut cell

**Line 2: q = k - p = 1 - p**
- At pM=2.4: q=-1.4 (below cell)
- At pP=2.6: q=-1.6 (below cell)
- Doesn't cut cell

**Line 3: q = p - k = p - 1**
- At pM=2.4: q=1.4 (above cell top qP=0.52)
- At pP=2.6: q=1.6 (above cell top)
- **This line cuts the cell!** It enters from left at q=0.52 (qP)

Actually, if the line q = p - 1 is at q=1.4 when p=2.4, and the cell top is at q=0.52, then the line is ABOVE the cell and doesn't cut it.

Let me reconsider with a better example...

## Scenario 2 (Revised): The Overlapping Cut Case

### Geometric Setup
Consider a triangular cell near a corner where all three boundaries converge:
- k = 1.0
- p = 1.1  (just above k)
- q = 1.05 (between p-k and k+p)

Cell boundaries:
- pM = 1.05, pP = 1.15
- qM = 1.00, qP = 1.10

### Boundary Lines
1. q = k + p = 1 + p  →  at p=1.1: q = 2.1 (above cell)
2. q = k - p = 1 - p  →  at p=1.1: q = -0.1 (below cell)
3. q = p - k = p - 1  →  at p=1.1: q = 0.1 (below cell)

Hmm, these also don't cut the cell. The issue is that I need to find where boundaries actually intersect the cell.

## The Actual Problem: Algorithmic, Not Geometric

After analyzing the code more carefully, the error scenarios are:

### Error Scenario A: Precision Loss in `polyarea`
**Where**: `centroidOfEdgeCell.m` uses `polyarea` (indirectly via shoelace formula)

When cell is very small (area < 1e-10), accumulated floating-point errors in:
- Finding intersection points
- Sorting vertices
- Shoelace summation

can exceed absolute threshold of 1e-4.

**Example**:
- k = 0.01, cell area ≈ 1e-8
- Relative error of 0.1% → absolute error = 1e-11 (OK)
- But if relative error is 10% → absolute error = 1e-9 (still OK)
- Need ~10000% relative error to trigger 1e-4 threshold!

So this is unlikely unless there's a catastrophic failure.

### Error Scenario B: Sign Error in Cutting Functions
**Where**: `cutBykPlusP.m`, `cutBykMinusP.m`, `cutByPMinusK.m`

The cutting functions check corner signs and build a polygon. If the sign logic is wrong, they might:
- Include wrong corners
- Order vertices incorrectly (giving negative area)
- Miss an intersection point

**Evidence**: Line 76-78 in `cutByPMinusK.m`:
```matlab
dA = polyarea(x(1:index),y(1:index));
if dA < 0
    disp('ohno')
end
```

This suggests negative areas DO occur!

### Error Scenario C: The Double-Conversion Issue
**Where**: Lines 81, 101, 122 in `midpoint2dShoelace.m`

```matlab
dAcutByKPlusP = cutBykPlusP(p,q,k,pM,pP,qM,qP);  % Returns "area including center"
dAcutByKPlusP = A_rectangle-dAcutByKPlusP;       % Convert to "area NOT including center"
```

If the cutting function returns an area LARGER than A_rectangle (due to error), then `dAcutByKPlusP` becomes **negative**!

Then later:
```matlab
areas(pj,qj,kj) = A_rectangle - flag1*dAcutByKPlusP - ...  % Subtracting negative = adding!
```

This inverts the intended logic.

## The Real Culprit: Inconsistent Polygon Construction

After careful review, I believe the core issue is:

**The two methods construct different polygons:**

1. **Subtraction method** (Method 1):
   - Each cutting function builds a polygon independently
   - Assumes the cut regions don't overlap
   - Combines them with simple +/- arithmetic

2. **Shoelace method** (Method 2):
   - `centroidOfEdgeCell` builds ONE polygon representing the actual intersection
   - Directly accounts for all boundary constraints
   - Uses the correct, unified polygon

**When they differ**: If two or more boundaries cut the cell, Method 1 computes:
```
Area = Rectangle - Cut1 - Cut2
```

But the correct area is:
```
Area = Rectangle - Union(Cut1, Cut2)
```

If Cut1 and Cut2 overlap, `Union(Cut1, Cut2) < Cut1 + Cut2`, so Method 1 subtracts too much.

This explains why errors occur when `flag1 + flag2 + flag3 > 1`.

## Testing Recommendation

To confirm this hypothesis, run the diagnostic and check:
1. Are errors more common when multiple flags are active?
2. Are errors systematically in one direction (Method 1 < Method 2 or vice versa)?
3. Do errors occur at specific k values or uniformly distributed?

The diagnostic script `diagnoseAreaErrors.m` will answer these questions.
