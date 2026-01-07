# Vertex Ordering Bug Analysis in Cutting Functions

## The Likely Culprit: Incorrect Polygon Vertex Order

After reconsidering the geometry, the most likely error source is **incorrect vertex ordering** in the cutting functions, not overlapping cuts.

## How the Cutting Functions Work

Each function (cutBykPlusP, cutBykMinusP, cutByPMinusK) builds a polygon by:

1. **Evaluate corner signs**: Check which of the 4 cell corners are on the center's side of the boundary
2. **Find edge intersections**: Where the boundary line crosses cell edges
3. **Build vertex list**: Add corners and intersections to arrays x[], y[]
4. **Compute area**: Call `polyarea(x(1:index), y(1:index))`

## The Critical Assumption

`polyarea` requires vertices in **consecutive order** (either clockwise or counterclockwise). If vertices are out of order, the result is **wrong or negative**.

## Where the Bug Likely Occurs

**Location**: Lines 34-73 in each cutting function

The vertex addition logic:
```matlab
index = 0;
if c1s*centerSign > 0
    index = index+1;
    y(index) = qP;
    x(index) = pM;
end
if (s1Flag == 1)
    index = index + 1;
    x(index) = star1(1);
    y(index) = star1(2);
end
if c2s*centerSign > 0
    index = index+1;
    y(index) = qP;
    x(index) = pP;
end
% ... etc for all 4 corners and 4 possible edge intersections
```

**The pattern**: Add vertices by going around the rectangle clockwise:
- Corner 1 (top-left): (pM, qP)
- Intersection 1-2: on top edge
- Corner 2 (top-right): (pP, qP)
- Intersection 2-3: on right edge
- Corner 3 (bottom-right): (pP, qM)
- Intersection 3-4: on bottom edge
- Corner 4 (bottom-left): (pM, qM)
- Intersection 4-1: on left edge

**This should work IF:**
- Corners are checked in order: 1 → 2 → 3 → 4
- Intersections are inserted between the correct corners
- Each intersection appears exactly once

## Potential Bug #1: Intersection Point Formulas

**In cutBykPlusP.m** (line q = k + p):

```matlab
if c1s*c2s<0 %intersection between corners 1 and 2 (on top edge where q=qP)
    star1 = [qP-k, qP];  % Solving qP = k + p  →  p = qP - k
    s1Flag = 1;
end
```

This finds p where line q=k+p crosses the top edge (q=qP). ✓ Correct

```matlab
if c2s*c3s<0  % intersection between corners 2 and 3 (on right edge where p=pP)
    star2 = [pP, k+pP];  % Solving q = k + pP  →  q = k + pP
    s2Flag = 1;
end
```

This finds q where line crosses right edge (p=pP). ✓ Correct

**Checking cutBykMinusP.m** (line q = k - p):

```matlab
if c1s*c2s<0  % top edge, q = qP
    star1 = [k-qP, qP];  % Solving qP = k - p  →  p = k - qP
    s1Flag = 1;
end
```

✓ Correct

**Checking cutByPMinusK.m** (line q = p - k):

```matlab
if c1s*c2s<0  % top edge, q = qP
    star1 = [qP+k, qP];  % Solving qP = p - k  →  p = qP + k
    s1Flag = 1;
end
```

✓ Correct

So the **intersection formulas appear correct**.

## Potential Bug #2: Sign Logic Error

The condition for including a corner:
```matlab
if c1s*centerSign > 0
```

This includes the corner if it has the **same sign** as the center.

**For cutBykPlusP**:
- Line: q = k + p  or  q - p - k = 0
- centerSign = q - p - k
- c1s = qP - pM - k
- If both positive: both are on the "q > k + p" side ✓
- If both negative: both are on the "q < k + p" side ✓

Seems correct!

## Potential Bug #3: Missing or Duplicate Vertices

The vertex addition is sequential:
```
if (corner1_included) add corner1
if (intersection1_exists) add intersection1
if (corner2_included) add corner2
if (intersection2_exists) add intersection2
...
```

**This is correct ONLY IF**:
- At most one intersection per edge (true - a line crosses an edge at most once)
- Corners and intersections alternate properly

**Problem case**: What if the polygon only includes ONE corner?

Example: Line cuts through two opposite edges, including only corner 1.
- Corner 1: included
- Intersection 1-2: exists (line crosses top edge)
- Corner 2: NOT included
- Intersection 2-3: exists (line crosses right edge)
- Corner 3: NOT included
- Corner 4: NOT included

Vertex order: [corner1, star1, star2]

But this is NOT in clockwise order! We have:
- corner1 = (pM, qP) = top-left
- star1 = somewhere on top edge
- star2 = somewhere on right edge

If star1 is to the RIGHT of corner 1, the order is: (pM,qP) → (star1_x, qP) → (pP, star2_y)

That's clockwise along the cell boundary... but wait, we're trying to construct the polygon that's on the CENTER's side of the line, not the cell boundary.

## AH! The Real Bug

The cutting function is supposed to return "area that includes center point" - meaning the polygon formed by the cell vertices/edges that are on the center's side of the boundary line.

But the vertex list being constructed goes around the **cell boundary**, not around the **polygon boundary**!

**Example**:
- Cell: [0, 1] × [0, 1]
- Line: q = 0.5 (horizontal line through middle)
- Center: (0.5, 0.3) → center is BELOW the line

Correct polygon (points where q < 0.5):
- (0, 0), (1, 0), (1, 0.5), (0, 0.5)

What the cutting function builds:
- Corner 1 (0,1): q=1 > 0.5 → NOT included
- Intersection on top edge: NONE (line doesn't cross q=1)
- Corner 2 (1,1): NOT included
- Intersection on right edge: (1, 0.5) → included
- Corner 3 (1,0): q=0 < 0.5 → included
- Intersection on bottom edge: NONE
- Corner 4 (0,0): included
- Intersection on left edge: (0, 0.5) → included

Vertex list: [(1,0.5), (1,0), (0,0), (0,0.5)]

This gives the correct polygon! And it's in the right order (clockwise).

Hmm, so maybe the logic IS correct after all...

## Alternative: Numerical Precision Issues

If the logic is correct, maybe the errors are due to:

1. **Near-boundary cases**: When a corner is EXACTLY on the boundary line (sign = 0), the logic might fail
2. **Floating point comparison**: `c1s*c2s < 0` might miss cases where one value is ~1e-16
3. **polyarea precision**: For very small or very large polygons, accumulated rounding errors
4. **Coordinate transformation**: centroidOfEdgeCell translates coordinates, cutting functions don't

## Diagnostic Approach

To find the bug, when an error occurs:
1. **Print the vertex lists** from both methods
2. **Plot the polygons** to visually confirm which is correct
3. **Check for negative areas** - indicates vertex ordering problem
4. **Look for degenerate cases** - e.g., only 2 vertices (line passes through corner)

The diagnostic script should be enhanced to capture this information.
