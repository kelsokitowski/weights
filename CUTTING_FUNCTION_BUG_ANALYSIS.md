# Deep Dive: Potential Bug in Cutting Function Vertex Ordering

## The Vertex Addition Pattern

Each cutting function adds vertices in this order:
1. Corner 1 (top-left, pM, qP) - if on center's side
2. Intersection on top edge (q=qP) - if exists
3. Corner 2 (top-right, pP, qP) - if on center's side
4. Intersection on right edge (p=pP) - if exists
5. Corner 3 (bottom-right, pP, qM) - if on center's side
6. Intersection on bottom edge (q=qM) - if exists
7. Corner 4 (bottom-left, pM, qM) - if on center's side
8. Intersection on left edge (p=pM) - if exists

This traverses the rectangle **clockwise** starting from top-left.

## Let me trace through a specific case

### Setup
- Cell: [1.0, 2.0] × [1.0, 2.0] (for simplicity)
- Boundary: q = p (slope = 1, passes through origin)
- This is line 3: q = p - k with k=0
- Center: (1.5, 1.5) - EXACTLY on the line

Actually, wait - the boundaries are fixed by k, not arbitrary. Let me use the actual boundary lines.

### Revised Setup: Test cutByPMinusK with a specific case

**Boundary**: q = p - k (line 3)
**Let k = 0.5**
**Line equation**: q = p - 0.5

**Cell**: [1.0, 2.0] × [1.0, 2.0]
**Center**: (1.5, 1.5)
**Center sign**: q + k - p = 1.5 + 0.5 - 1.5 = 0.5 (POSITIVE, above line)

**Corner signs** (using q + k - p):
- c1 (pM=1.0, qP=2.0): 2.0 + 0.5 - 1.0 = 1.5 (positive)
- c2 (pP=2.0, qP=2.0): 2.0 + 0.5 - 2.0 = 0.5 (positive)
- c3 (pP=2.0, qM=1.0): 1.0 + 0.5 - 2.0 = -0.5 (negative)
- c4 (pM=1.0, qM=1.0): 1.0 + 0.5 - 1.0 = 0.5 (positive)

**Sign changes** (indicating intersections):
- c1*c2 = 1.5 * 0.5 > 0 → no intersection on top edge
- c2*c3 = 0.5 * (-0.5) < 0 → **intersection on right edge**
- c3*c4 = (-0.5) * 0.5 < 0 → **intersection on bottom edge**
- c4*c1 = 0.5 * 1.5 > 0 → no intersection on left edge

**Intersection points**:

Right edge (p=pP=2.0): q = p - k = 2.0 - 0.5 = 1.5
- `star2 = [pP, -k+pP] = [2.0, 1.5]` ✓ Correct

Bottom edge (q=qM=1.0): p = q + k = 1.0 + 0.5 = 1.5
- `star3 = [qM+k, qM] = [1.5, 1.0]` ✓ Correct

**Vertices added** (with centerSign = 0.5 > 0):

1. `if c1s*centerSign > 0`: (1.5)(0.5) > 0 ✓ → Add corner 1: (1.0, 2.0)
2. `if s1Flag`: No → skip
3. `if c2s*centerSign > 0`: (0.5)(0.5) > 0 ✓ → Add corner 2: (2.0, 2.0)
4. `if s2Flag`: Yes → Add star2: (2.0, 1.5)
5. `if c3s*centerSign > 0`: (-0.5)(0.5) < 0 ✗ → Skip corner 3
6. `if s3Flag`: Yes → Add star3: (1.5, 1.0)
7. `if c4s*centerSign > 0`: (0.5)(0.5) > 0 ✓ → Add corner 4: (1.0, 1.0)
8. `if s4Flag`: No → skip

**Final vertex list**: [(1.0, 2.0), (2.0, 2.0), (2.0, 1.5), (1.5, 1.0), (1.0, 1.0)]

**Is this clockwise?**
- (1.0, 2.0) → (2.0, 2.0): Move right along top edge ✓
- (2.0, 2.0) → (2.0, 1.5): Move down along right edge ✓
- (2.0, 1.5) → (1.5, 1.0): Move diagonally down-left **following the cut line** ✓
- (1.5, 1.0) → (1.0, 1.0): Move left along bottom edge ✓
- (1.0, 1.0) → (1.0, 2.0): Move up along left edge ✓

**This forms a clockwise pentagon!** Area should be correct.

**Check with shoelace formula**:
Area = 0.5 * |sum((x[i]*y[i+1] - x[i+1]*y[i]))|

Let me compute:
- (1.0, 2.0) to (2.0, 2.0): 1.0*2.0 - 2.0*2.0 = 2.0 - 4.0 = -2.0
- (2.0, 2.0) to (2.0, 1.5): 2.0*1.5 - 2.0*2.0 = 3.0 - 4.0 = -1.0
- (2.0, 1.5) to (1.5, 1.0): 2.0*1.0 - 1.5*1.5 = 2.0 - 2.25 = -0.25
- (1.5, 1.0) to (1.0, 1.0): 1.5*1.0 - 1.0*1.0 = 1.5 - 1.0 = 0.5
- (1.0, 1.0) to (1.0, 2.0): 1.0*2.0 - 1.0*1.0 = 2.0 - 1.0 = 1.0

Sum = -2.0 - 1.0 - 0.25 + 0.5 + 1.0 = -1.75
Area = 0.5 * |-1.75| = 0.875

**Manual verification**:
The polygon is the upper-left portion of the square above the line q = p - 0.5.
- Full square area: 1.0 × 1.0 = 1.0
- Triangle below line: vertices (2.0, 1.0), (2.0, 1.5), (1.5, 1.0)
  - Base = 0.5, Height = 0.5
  - Area = 0.5 * 0.5 * 0.5 = 0.125
- Polygon area = 1.0 - 0.125 = 0.875 ✓ **Matches!**

So the cutting function logic appears **CORRECT** for this case.

## Testing Case 2: Opposite Side

Same setup, but with center on the NEGATIVE side:
**Center**: (1.5, 0.9) (below the line q = p - 0.5 = 1.0)
**Center sign**: 0.9 + 0.5 - 1.5 = -0.1 (negative)

Same corners as before:
- c1 = 1.5 (positive)
- c2 = 0.5 (positive)
- c3 = -0.5 (negative)
- c4 = 0.5 (positive)

**Vertices added** (with centerSign = -0.1 < 0):

1. `if c1s*centerSign > 0`: (1.5)(-0.1) < 0 ✗ → Skip
2. `if s1Flag`: No → skip
3. `if c2s*centerSign > 0`: (0.5)(-0.1) < 0 ✗ → Skip
4. `if s2Flag`: Yes → Add star2: (2.0, 1.5)
5. `if c3s*centerSign > 0`: (-0.5)(-0.1) > 0 ✓ → Add corner 3: (2.0, 1.0)
6. `if s3Flag`: Yes → Add star3: (1.5, 1.0)
7. `if c4s*centerSign > 0`: (0.5)(-0.1) < 0 ✗ → Skip
8. `if s4Flag`: No → skip

**Final vertex list**: [(2.0, 1.5), (2.0, 1.0), (1.5, 1.0)]

**This is the triangle!** Area should be 0.125.

**Check ordering**:
- (2.0, 1.5) → (2.0, 1.0): Down along right edge ✓
- (2.0, 1.0) → (1.5, 1.0): Left along bottom edge ✓
- (1.5, 1.0) → (2.0, 1.5): Diagonally up-right along cut line ✓

Clockwise ordering ✓

**Shoelace**:
- (2.0, 1.5) to (2.0, 1.0): 2.0*1.0 - 2.0*1.5 = 2.0 - 3.0 = -1.0
- (2.0, 1.0) to (1.5, 1.0): 2.0*1.0 - 1.5*1.0 = 2.0 - 1.5 = 0.5
- (1.5, 1.0) to (2.0, 1.5): 1.5*1.5 - 2.0*1.0 = 2.25 - 2.0 = 0.25

Sum = -1.0 + 0.5 + 0.25 = -0.25
Area = 0.5 * |-0.25| = 0.125 ✓ **Correct!**

## Conclusion from Manual Testing

The cutting function logic appears **mathematically correct** for these test cases:
- Intersection points computed correctly
- Vertices added in correct clockwise order
- polyarea should return correct result

## So Where Are the Errors Coming From?

### Hypothesis 1: Numerical Precision
For very small cells or extreme k values, floating-point errors could accumulate:
- Computing intersections: `star2 = [pP, -k+pP]` could have rounding errors
- polyarea internal calculations
- The comparison threshold `c1s*c2s < 0` could miss intersections if one value is ~1e-16

### Hypothesis 2: Boundary Cases with Zero Signs
When a corner lies EXACTLY on the boundary line:
- Corner sign = 0
- `c1s*c2s = 0` (not < 0), so intersection not detected
- But the corner IS on the line, so it's both an intersection AND a corner
- Might be added twice or not at all

### Hypothesis 3: Different Numerical Paths
Method 1 (cutting functions):
- Computes rectangle area
- Subtracts/adds cut areas
- Multiple arithmetic operations

Method 2 (centroidOfEdgeCell):
- Directly builds polygon vertices
- Translates coordinates by (pM, qM)
- Single shoelace calculation
- Takes absolute value

Even with perfect logic, different numerical operations can accumulate errors differently.

### Hypothesis 4: The Double Conversion
In midpoint2dShoelace.m, line 81:
```matlab
dAcutByKPlusP = cutBykPlusP(p,q,k,pM,pP,qM,qP);  % Returns area including center
dAcutByKPlusP = A_rectangle-dAcutByKPlusP;       % Convert to area NOT including center
```

If `cutBykPlusP` returns a value slightly LARGER than A_rectangle due to rounding:
- `dAcutByKPlusP` becomes **negative**!
- Later: `areas = A_rectangle - dAcutByKPlusP` adds instead of subtracts!
- This completely inverts the result

**This is the most likely source of errors!**

## Recommendation: Check for Negative Intermediate Values

Add logging to check if `dAcutByKPlusP`, `dAcutByKMinusP`, or `dAcutByPMinusK` ever become negative after the conversion step (lines 81, 101, 122).

If so, that explains the errors - the cutting function is returning a value larger than A_rectangle due to numerical precision, causing the conversion to produce a negative value.
