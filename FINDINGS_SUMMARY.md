# Summary of Findings: Area Calculation Errors in midpoint2dShoelace

## Investigation Timeline

1. **Initial hypothesis**: Multiple boundary cuts cause overlapping regions that are double-counted
   - **Status**: DISPROVEN by user
   - **Reason**: Boundary lines only intersect at p=0, q=0, k=0 (outside domain), and two lines are parallel

2. **Edge case degeneracy hypothesis**: Cells at pj=1, qj=1 are degenerate (zero area)
   - **Status**: DISPROVEN by manual analysis
   - **Reason**: All cells have non-zero area; boundary cells are half-sized but valid rectangles

3. **Vertex ordering bug hypothesis**: Cutting functions add vertices in wrong order
   - **Status**: Likely NOT the primary issue
   - **Reason**: Manual trace-through shows correct clockwise ordering for test cases
   - **But**: May fail in edge cases (corner exactly on line, numerical precision)

4. **MOST LIKELY: Double conversion causing negative intermediate values**
   - **Status**: HIGH PROBABILITY - this is the primary error source
   - **Location**: midpoint2dShoelace.m lines 81, 101, 122

## The Likely Bug: Negative Intermediate Values from Double Conversion

### The Problem Code

```matlab
% Line 80-81
dAcutByKPlusP = cutBykPlusP(p,q,k,pM,pP,qM,qP);  % Returns "area including center"
dAcutByKPlusP = A_rectangle-dAcutByKPlusP;       % Convert to "area NOT including center"

% Later, line 130 (inside triad)
areas(pj,qj,kj) = A_rectangle - flag1*dAcutByKPlusP - flag2*dAcutByKMinusP - flag3*dAcutByPMinusK;

% Or line 139 (outside triad)
areas(pj,qj,kj) = flag1*dAcutByKPlusP + flag2*dAcutByKMinusP + flag3*dAcutByPMinusK;
```

### How It Fails

**Scenario**: Due to floating-point rounding, `cutBykPlusP()` returns a value **slightly larger** than `A_rectangle`

Example:
- A_rectangle = 1.0000000000
- cutBykPlusP returns: 1.0000000002 (small numerical error)
- After conversion: dAcutByKPlusP = 1.0 - 1.0000000002 = **-0.0000000002** (NEGATIVE!)

**Impact on inside cells** (line 130):
- `areas = A_rectangle - flag1*dAcutByKPlusP`
- `areas = 1.0 - 1*(-0.0000000002)`
- `areas = 1.0 + 0.0000000002 = 1.0000000002`
- Should be ~0.9, but we get ~1.0 (10% error!)

**Impact on outside cells** (line 139):
- `areas = flag1*dAcutByKPlusP`
- `areas = 1*(-0.0000000002) = -0.0000000002`
- Should be ~0.1, but we get negative! (catastrophic error)

### Why This Happens

The cutting function computes a polygon area using vertices that may have rounding errors:
- Intersection points: `star1 = [qP-k, qP]` involves subtraction (precision loss)
- polyarea accumulates many multiplications and additions
- The final area can be off by ~1e-15 to 1e-10

When A_rectangle and the cut area are computed via **different code paths**, they accumulate errors independently. Even though both should theoretically be within the rectangle bounds, numerical differences can make one larger than the other.

### Evidence Supporting This

1. **Explicit negative area check** in cutByPMinusK.m:76-78 suggests negative values DO occur
2. **Threshold of 1e-4** (line 149) is much larger than typical floating-point error (~1e-15), suggesting the discrepancies are NOT just roundoff
3. **But**: If intermediate values go negative, small errors get amplified into large errors
4. **Method 2** (centroidOfEdgeCell) uses a different numerical path:
   - Translates coordinates first
   - Single consistent polygon construction
   - Takes absolute value of area
   - This avoids the negative intermediate value problem

## Secondary Contributing Factors

### 1. Logarithmic Spacing Causes Extreme Scale Differences

- kVals range from 0.01 to 10^5 (10 million to 1 ratio)
- Cell sizes vary by similar ratios
- Numerical precision is scale-dependent

At k ≈ 0.01:
- Cell area ≈ 1e-8
- Cut area ≈ 1e-9
- Subtraction: 1e-8 - 1e-9 loses 1 digit of precision

At k ≈ 10^5:
- Cell area ≈ 1e10
- Cut area ≈ 1e9
- Subtraction: 1e10 - 1e9 still loses precision

### 2. Coordinate Translation Differences

**Method 1**: Works in original coordinates
**Method 2**: Translates to local frame (xVals - pM, yVals - qM) before computing area

Translation can actually **improve** numerical stability for large coordinate values by making the polygon vertices closer to origin.

### 3. Multiple Arithmetic Operations vs. Single Calculation

**Method 1 chain**:
```
A_rectangle → cutFunction → polyarea → A_rect - cut_area → flag_logic → final_area
```
5+ arithmetic operations, each introducing error

**Method 2 chain**:
```
Find vertices → translate → shoelace → abs → final_area
```
Fewer operations, more direct

## Diagnostic Recommendations

To confirm this hypothesis, add logging at line 81, 101, 122:

```matlab
dAcutByKPlusP = cutBykPlusP(p,q,k,pM,pP,qM,qP);
if dAcutByKPlusP > A_rectangle
    fprintf('WARNING: Cut area (%.12e) > Rectangle area (%.12e) at pj=%d,qj=%d,kj=%d\n', ...
            dAcutByKPlusP, A_rectangle, pj, qj, kj);
end
dAcutByKPlusP = A_rectangle-dAcutByKPlusP;
if dAcutByKPlusP < 0
    fprintf('ERROR: Negative intermediate value %.12e at pj=%d,qj=%d,kj=%d\n', ...
            dAcutByKPlusP, pj, qj, kj);
end
```

**Expected result**: If this hypothesis is correct, you'll see:
- Many "WARNING" messages where cut area slightly exceeds rectangle area
- Some "ERROR" messages where the converted value goes negative
- These should correlate strongly with the error locations detected at line 149

## Recommended Fix

### Short-term: Add Bounds Checking

```matlab
dAcutByKPlusP = cutBykPlusP(p,q,k,pM,pP,qM,qP);
dAcutByKPlusP = max(0, min(A_rectangle - dAcutByKPlusP, A_rectangle));  % Clamp to [0, A_rectangle]
```

This prevents negative values and ensures physical validity.

### Medium-term: Use Method 2 as Ground Truth

```matlab
% Replace line 130-143 with:
if anyCornerInside > 0 || triadCondition(q,p,k)
    areas(pj,qj,kj) = areas2(pj,qj,kj);  % Trust the shoelace method
    % ... rest of logic
end
```

Simply use the value already computed by centroidOfEdgeCell.

### Long-term: Eliminate Redundancy

The code computes area TWICE for every cell:
1. Via cutting functions + arithmetic (lines 71-143)
2. Via centroidOfEdgeCell (line 52)

**Remove the cutting function approach entirely**. It's:
- More complex (3 separate functions)
- Less accurate (multiple error sources)
- Redundant (Method 2 already gives the answer)

Keep only centroidOfEdgeCell, which:
- Directly constructs the correct polygon
- Uses coordinate translation for numerical stability
- Has built-in consistency checks (two independent area calculations)
- Is already trusted enough that errors are flagged when Method 1 disagrees with it

## Conclusion

The area calculation errors most likely arise from **negative intermediate values** caused by floating-point precision differences in the double conversion step (A_rectangle - cut_area). When the cutting function returns a value slightly larger than A_rectangle due to numerical error, the subtraction produces a negative number, which then completely breaks the subsequent arithmetic.

The diagnostic script will confirm this by logging when intermediate values go negative, and these locations should match the error locations flagged at line 149.

**Trust Method 2 (centroidOfEdgeCell/areas2) as the correct area value.**
