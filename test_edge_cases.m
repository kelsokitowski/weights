% Edge Case Analysis: pj=1, qj=1 Degeneracy Handling
%
% This script traces through the logic for boundary cells to check if
% the cutting functions properly handle degenerate (half-sized) cells.

%% Setup: Create a small test case
kVals = logspace(log10(0.01), log10(10), 10);  % Small test grid
kLength = length(kVals);

fprintf('Testing edge cases at pj=1, qj=1\n');
fprintf('kVals: %s\n\n', mat2str(kVals, 3));

%% Case 1: pj=1, qj=1 (corner cell)
fprintf('=== CASE 1: pj=1, qj=1 (corner cell) ===\n');
pj = 1; qj = 1; kj = 3;  % Pick middle k value
p = kVals(pj);
q = kVals(qj);
k = kVals(kj);

fprintf('Indices: pj=%d, qj=%d, kj=%d\n', pj, qj, kj);
fprintf('Values: p=%.4f, q=%.4f, k=%.4f\n', p, q, k);

% Get corners using the actual function logic
[pM, pP, qM, qP] = getCorners(pj, qj, kLength, p, q, kVals);

fprintf('Cell boundaries from getCorners:\n');
fprintf('  p: [%.6f, %.6f]\n', pM, pP);
fprintf('  q: [%.6f, %.6f]\n', qM, qP);
fprintf('  Cell dimensions: %.6f × %.6f\n', pP-pM, qP-qM);
fprintf('  A_rectangle = %.8f\n', (pP-pM)*(qP-qM));

% Check what getCorners SHOULD return
fprintf('\nManual calculation for pj=1:\n');
if pj < kLength
    pP_calc = p + (kVals(pj+1) - kVals(pj))/2;
else
    pP_calc = p;
end
if pj > 1
    pM_calc = p - (p - kVals(pj-1))/2;
else
    pM_calc = p;  % DEGENERATE: pM = p
end
fprintf('  pM should be: %.6f (is %.6f) %s\n', pM_calc, pM, isequal(pM, pM_calc));
fprintf('  pP should be: %.6f (is %.6f) %s\n', pP_calc, pP, isequal(pP, pP_calc));

fprintf('\nManual calculation for qj=1:\n');
if qj < kLength
    qP_calc = q + (kVals(qj+1) - q)/2;
else
    qP_calc = q;
end
if qj > 1
    qM_calc = q - (q - kVals(qj-1))/2;
else
    qM_calc = q;  % DEGENERATE: qM = q
end
fprintf('  qM should be: %.6f (is %.6f) %s\n', qM_calc, qM, isequal(qM, qM_calc));
fprintf('  qP should be: %.6f (is %.6f) %s\n', qP_calc, qP, isequal(qP, qP_calc));

fprintf('\n*** DEGENERACY: pM=p=%.6f and qM=q=%.6f ***\n', pM, qM);
fprintf('*** Cell is actually a single point: (%.6f, %.6f) ***\n', p, q);
fprintf('*** Rectangle area = %.12f (should be zero!) ***\n\n', (pP-pM)*(qP-qM));

%% Case 2: pj=1, qj=2 (left edge, not corner)
fprintf('\n=== CASE 2: pj=1, qj=2 (left edge) ===\n');
pj = 1; qj = 2; kj = 3;
p = kVals(pj);
q = kVals(qj);
k = kVals(kj);

fprintf('Indices: pj=%d, qj=%d, kj=%d\n', pj, qj, kj);
fprintf('Values: p=%.4f, q=%.4f, k=%.4f\n', p, q, k);

[pM, pP, qM, qP] = getCorners(pj, qj, kLength, p, q, kVals);

fprintf('Cell boundaries:\n');
fprintf('  p: [%.6f, %.6f]  (width = %.6f)\n', pM, pP, pP-pM);
fprintf('  q: [%.6f, %.6f]  (height = %.6f)\n', qM, qP, qP-qM);
fprintf('  A_rectangle = %.8f\n', (pP-pM)*(qP-qM));

if pM == p
    fprintf('*** DEGENERACY: pM=p=%.6f (left edge collapsed) ***\n', pM);
    fprintf('*** Cell is a vertical line segment! ***\n');
end

%% Case 3: pj=2, qj=1 (bottom edge, not corner)
fprintf('\n=== CASE 3: pj=2, qj=1 (bottom edge) ===\n');
pj = 2; qj = 1; kj = 3;
p = kVals(pj);
q = kVals(qj);
k = kVals(kj);

fprintf('Indices: pj=%d, qj=%d, kj=%d\n', pj, qj, kj);
fprintf('Values: p=%.4f, q=%.4f, k=%.4f\n', p, q, k);

[pM, pP, qM, qP] = getCorners(pj, qj, kLength, p, q, kVals);

fprintf('Cell boundaries:\n');
fprintf('  p: [%.6f, %.6f]  (width = %.6f)\n', pM, pP, pP-pM);
fprintf('  q: [%.6f, %.6f]  (height = %.6f)\n', qM, qP, qP-qM);
fprintf('  A_rectangle = %.8f\n', (pP-pM)*(qP-qM));

if qM == q
    fprintf('*** DEGENERACY: qM=q=%.6f (bottom edge collapsed) ***\n', qM);
    fprintf('*** Cell is a horizontal line segment! ***\n');
end

%% Case 4: pj=kLength, qj=kLength (top-right corner)
fprintf('\n=== CASE 4: pj=kLength, qj=kLength (top-right corner) ===\n');
pj = kLength; qj = kLength; kj = 3;
p = kVals(pj);
q = kVals(qj);
k = kVals(kj);

fprintf('Indices: pj=%d, qj=%d, kj=%d\n', pj, qj, kj);
fprintf('Values: p=%.4f, q=%.4f, k=%.4f\n', p, q, k);

[pM, pP, qM, qP] = getCorners(pj, qj, kLength, p, q, kVals);

fprintf('Cell boundaries:\n');
fprintf('  p: [%.6f, %.6f]  (width = %.6f)\n', pM, pP, pP-pM);
fprintf('  q: [%.6f, %.6f]  (height = %.6f)\n', qM, qP, qP-qM);
fprintf('  A_rectangle = %.8f\n', (pP-pM)*(qP-qM));

if pP == p
    fprintf('*** DEGENERACY: pP=p=%.6f (right edge collapsed) ***\n', pP);
end
if qP == q
    fprintf('*** DEGENERACY: qP=q=%.6f (top edge collapsed) ***\n', qP);
end
if pP == p && qP == q
    fprintf('*** Cell is a single point! ***\n');
end

%% Test how cutting functions handle degenerate cells

fprintf('\n\n=== TESTING CUTTING FUNCTIONS WITH DEGENERATE CELLS ===\n');

% Test Case: pj=1, qj=1 cell (point) being "cut"
pj = 1; qj = 1; kj = 5;
p = kVals(pj);
q = kVals(qj);
k = kVals(kj);

[pM, pP, qM, qP] = getCorners(pj, qj, kLength, p, q, kVals);
A_rectangle = (pP-pM)*(qP-qM);

fprintf('\nTest: Cutting a degenerate cell (pj=1, qj=1)\n');
fprintf('Cell: [%.6f, %.6f] × [%.6f, %.6f]\n', pM, pP, qM, qP);
fprintf('Rectangle area: %.12f\n', A_rectangle);
fprintf('k=%.4f, p=%.4f, q=%.4f\n', k, p, q);

% Check if boundary 1 (q = k+p) cuts this cell
fprintf('\nBoundary 1: q = k + p\n');
centerSign = q - p - k;
fprintf('  Center sign: %.6f\n', centerSign);

c1s = (qP-k-pM); % corner 1 (pM, qP)
c2s = (qP-k-pP); % corner 2 (pP, qP)
c3s = (qM-k-pP); % corner 3 (pP, qM)
c4s = (qM-k-pM); % corner 4 (pM, qM)

fprintf('  Corner signs: c1=%.6f, c2=%.6f, c3=%.6f, c4=%.6f\n', c1s, c2s, c3s, c4s);

% Check for sign changes (indicating cut)
cuts = [c1s*c2s < 0, c2s*c3s < 0, c3s*c4s < 0, c4s*c1s < 0];
fprintf('  Sign changes (cuts): [%d %d %d %d]\n', cuts);

if any(cuts)
    fprintf('  *** Boundary cuts the degenerate cell! ***\n');
    try
        dA = cutBykPlusP(p, q, k, pM, pP, qM, qP);
        fprintf('  cutBykPlusP returned: %.12f\n', dA);
        dA_converted = A_rectangle - dA;
        fprintf('  After conversion: %.12f\n', dA_converted);
    catch ME
        fprintf('  ERROR calling cutBykPlusP: %s\n', ME.message);
    end
else
    fprintf('  No cut detected\n');
end

%% Summary and analysis
fprintf('\n\n=== SUMMARY ===\n');
fprintf('PROBLEM IDENTIFIED:\n');
fprintf('1. At pj=1 or qj=1, getCorners returns pM=p or qM=q\n');
fprintf('2. This makes cells degenerate (zero width or height)\n');
fprintf('3. For pj=1 AND qj=1, the cell is a SINGLE POINT\n');
fprintf('4. Rectangle area = 0, but code still calls cutting functions\n');
fprintf('5. Cutting functions may divide by zero or return NaN\n');
fprintf('6. Later arithmetic: A_rectangle - dA = 0 - dA = -dA (wrong sign!)\n');
fprintf('\nRECOMMENDATION:\n');
fprintf('Check if errors occur predominantly at pj=1, qj=1 in actual runs\n');
fprintf('If so, special handling needed for boundary cells\n');
