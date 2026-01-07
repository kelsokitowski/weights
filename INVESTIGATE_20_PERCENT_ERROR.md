# Investigation: Why 20% Error Persists

## Observation: Redundant areas2 Computation

The code computes areas2 TWICE:
1. **First loop** (lines 47-56): Only for `pj >= qj` (upper triangle), then copies via symmetry (line 163)
2. **Second loop** (lines 213-224): For ALL cells, overwriting the first computation

## Potential Issue: Are cells being summed correctly?

Looking at line 255:
```matlab
integralAreas2 = integralAreas2 + areas2(pj,qj,kj)*1;
```

This sums ALL cells. But which cells have non-zero areas2?

## Test: Check if the problem is in how cells are counted

Could you run this diagnostic to see where the error is concentrated?

```matlab
% Add after line 255 in the integral loop:
if areas2(pj,qj,kj) > 0
    fprintf('k=%d, pj=%d, qj=%d: areas2=%.6e, triad=%d\n', ...
            kj, pj, qj, areas2(pj,qj,kj), triadCondition(q,p,k));
end
```

This will show:
1. Which cells contribute to the sum
2. Whether any cells have areas2 > 0 but triadCondition = 0 (shouldn't happen)

## Alternative Theory: Grid Boundary Issue

The analytical formula integrates from 0 to max(kVals), but cells only cover [kVals(1), kVals(end)].

At the **bottom-left** corner (pj=1, qj=1), getCorners returns:
- pM = kVals(1), pP = midpoint between kVals(1) and kVals(2)
- qM = kVals(1), qP = similar

So the grid starts at kVals(1), NOT at 0.

**For large k**, the region [0, kVals(1)] × [0, kVals(1)] is:
- Included in analytical formula (integrates from 0)
- NOT included in cell sum (cells start at kVals(1))

This could cause systematic under-counting!

## Test: Adjust analytical formula

Try changing line 358 from:
```matlab
analytical = 2*k*max(kVals) - 1.5*k^2;
```
to:
```matlab
kmin = min(kVals);
kmax = max(kVals);
% Integrate from kmin instead of 0
if k <= kmin
    analytical = 0;  % No triad region in the grid
elseif k <= kmax
    analytical = 2*k*kmax - 1.5*k^2 - (2*k*kmin - 1.5*k^2);  % Subtract missing region
else
    analytical = 2*k*kmax - 1.5*k^2;  % Original
end
```

Actually wait, let me calculate this more carefully...

For the region [kmin, kmax] × [kmin, kmax], the triad area is NOT simply the original formula minus a constant. I need to rethink the integration bounds.

## Better Test: Verify what region is actually covered

Could you add this diagnostic at the beginning of the code:

```matlab
% After line 7
fprintf('Grid covers: p ∈ [%.6f, %.6f], q ∈ [%.6f, %.6f]\n', ...
        min(kVals), max(kVals), min(kVals), max(kVals));

% Check first cell
pj=1; qj=1;
[pM, pP, qM, qP] = getCorners(pj, qj, kLength, kVals(1), kVals(1), kVals);
fprintf('First cell: [%.6f, %.6f] × [%.6f, %.6f]\n', pM, pP, qM, qP);
fprintf('Does first cell start at 0? pM=%e, qM=%e\n', pM, qM);
```

This will tell us if the grid actually starts at kVals(1) or extends to 0.

## My Current Hypothesis

The 20% error is because:
1. Analytical formula assumes integration from **0** to max(kVals)
2. Grid cells only cover **kVals(1)** to max(kVals)
3. For large k, the missing region [0, kVals(1)] contributes significantly

**For k ≈ kmax = 100, kmin = 0.01:**
- Full triad area: 2(100)(100) - 1.5(100)² = 5000
- Missing region contribution: ???

Let me calculate properly for the triangular region at k=kmax...

Actually, can you tell me:
1. What is your kVals range? (min and max values)
2. At which k values is the error largest?
3. What is the actual error value (not just percent)?
