# Revised Error Analysis - midpoint2dShoelace

## Correction to Initial Hypothesis

**Initial claim (INCORRECT)**: "Cut regions overlap when multiple boundaries intersect a cell"

**Problem with this claim**: The three boundary lines only intersect at p=0, q=0, or k=0, which are outside the computational domain (kVals ≥ 0.01). Additionally:
- Lines 2 & 3 are parallel (both slope = 1), so they cannot both cut the same small cell
- For lines 1 & 2 to both cut a cell requires: cell_height > 2×p_coordinate (rare for log-spaced grid)

**Conclusion**: Multiple boundaries cutting the same cell is **rare, not the primary error source**.

## Alternative Error Sources

### 1. **Polygon Construction Bugs in Cutting Functions**

**Evidence from cutByPMinusK.m:76-78**:
```matlab
dA = polyarea(x(1:index),y(1:index));
if dA < 0
    disp('ohno')
end
```

The code explicitly checks for negative areas, indicating this **does occur**!

**Root cause**: The cutting functions build polygons by:
- Checking which corners are on the center's side of the boundary
- Adding intersection points where the boundary crosses cell edges
- Calling `polyarea(x, y)` on the vertex list

**Potential bugs**:
- **Incorrect vertex ordering**: `polyarea` requires vertices in order (CW or CCW). If vertices are added out of order, the result is wrong or negative.
- **Missing intersection points**: If the code fails to detect an edge crossing, the polygon is incomplete.
- **Duplicate vertices**: Adding the same point twice causes degenerate polygons.

**Location**: Lines 33-73 in each cutting function where vertices are added to x,y arrays

### 2. **Mismatched Polygon Construction: Method 1 vs Method 2**

The two methods construct **fundamentally different polygons**:

**Method 1 (Subtraction via cutting functions)**:
- Each cutting function independently computes area on one side of ONE boundary
- Ignores the other boundaries
- Results are combined arithmetically

**Method 2 (Shoelace via centroidOfEdgeCell)**:
- Directly constructs the polygon: `cell ∩ triad_region`
- Simultaneously considers ALL three boundaries
- Finds all intersection points with cell edges (centroidOfEdgeCell.m:7-159)

**Why they differ**:
Even with a single cutting boundary, the methods might disagree if:
- The cutting function orders vertices incorrectly
- The cutting function uses different intersection point calculations
- Numerical precision differs between the two methods

### 3. **The "Outside Cell" Logic Issue**

**Location**: midpoint2dShoelace.m:138-142

For cells where center is OUTSIDE but a piece is INSIDE:
```matlab
areas(pj,qj,kj) = flag1*dAcutByKPlusP + flag2*dAcutByKMinusP + flag3*dAcutByPMinusK;
```

This **adds** the cut pieces. But what does each piece represent?

After conversion: `dAcutByKPlusP = A_rectangle - cutBykPlusP(...)`

For an outside cell:
- `cutBykPlusP` returns area on center's side (outside the triad for this boundary)
- `dAcutByKPlusP` becomes the area on the OTHER side (inside the triad for this boundary)

So we're adding up pieces from different boundaries.

**The problem**: If multiple flags are active (rare but possible), we're adding:
- Piece inside boundary 1's region
- Piece inside boundary 2's region

But these pieces might **overlap** if both boundaries pass through the cell! Even though the boundaries don't intersect in the domain, they can both cut the same cell, and the "inside pieces" for each boundary would overlap.

**Wait** - this brings us back to overlapping regions, but now I understand it better...

### 4. **Numerical Precision in Different Code Paths**

**Method 1 path**:
1. Compute full rectangle area: `(pP-pM)*(qP-qM)`
2. Call cutting function → uses `polyarea` internally
3. Convert: `A_rectangle - cut_result`
4. Combine multiple cuts with +/-

**Method 2 path**:
1. Find all intersection points directly (centroidOfEdgeCell.m)
2. Sort vertices clockwise
3. Apply shoelace formula with translated coordinates (shifted by pM, qM)
4. Take absolute value of result

**Precision loss in Method 1**:
- Multiple arithmetic operations (A - cut1 - cut2...)
- Potential catastrophic cancellation when cutting a tiny piece from a large rectangle
- Each cutting function builds its polygon independently

**Example**:
- Cell area = 1.0
- Cut removes 0.9999
- Result should be 0.0001
- But if cut is computed as 0.9998 due to rounding → result is 0.0002 (100% error!)

### 5. **Edge Cases at Grid Boundaries**

**Location**: getCorners.m behavior at boundaries

At pj=1 or qj=1 (lower boundaries):
- pM = p (not p minus half-spacing)
- qM = q

At pj=kLength or qj=kLength (upper boundaries):
- pP = p (not p plus half-spacing)
- qP = q

This makes boundary cells **not rectangular** - they're half-cells. The cutting functions might not handle this correctly.

## Most Likely Error Source

Based on code inspection, I believe the **primary error source** is:

**Vertex ordering errors in cutting functions causing incorrect `polyarea` results**

Supporting evidence:
1. Explicit check for negative areas (shouldn't happen if vertices ordered correctly)
2. Complex conditional logic for adding vertices (lines 34-73 in each cutting function)
3. The shoelace method (Method 2) carefully sorts vertices clockwise (centroidOfEdgeCell.m:33-159)
4. Method 2 uses TWO independent shoelace implementations and checks consistency (centroidOfEdgeCell.m:175-187)

## Testing Strategy

To identify the actual error source:

1. **Run boundary_intersection_analysis.m**: Confirm how rare multi-cut cells actually are
2. **Check vertex ordering**: Add diagnostic to cutting functions to print vertex coordinates when called
3. **Compare specific cases**: When error occurs, manually verify which method is correct
4. **Check for negative areas**: Count how often `dA < 0` occurs in practice
5. **Test edge cells**: Check if errors concentrate at pj=1, qj=1, or boundary cells

## Revised Recommendation

The safest fix is to **trust Method 2 (centroidOfEdgeCell/shoelace)** because:
- It's more direct (one polygon, one calculation)
- It has built-in consistency checks
- It handles all boundaries simultaneously
- It carefully manages vertex ordering

Method 1 should be debugged or replaced, not relied upon.
