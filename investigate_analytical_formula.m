% Investigating why areas2 has errors increasing with k
%
% Theory: For large k, the triad region extends beyond the finite grid,
% causing the sum of cell areas to under-count the analytical area.

%% First, let's understand the analytical formula

% From midpoint2dShoelace.m line 358:
% analytical = 2*k*max(kVals) - 1.5*k^2;

% This should be the area of the triad region for a given k,
% integrated over the domain [0, max(kVals)] × [0, max(kVals)]

% Let's derive this analytically:
%
% Triad region: q ∈ [max(k-p, p-k), k+p]
%
% For p ∈ [0, k]: width(p) = (k+p) - (k-p) = 2p
% For p ∈ [k, ∞]: width(p) = (k+p) - (p-k) = 2k
%
% Area = ∫_0^k 2p dp + ∫_k^M 2k dp  (where M = max(kVals))
%      = [p²]_0^k + [2kp]_k^M
%      = k² + 2k(M-k)
%      = k² + 2kM - 2k²
%      = 2kM - k²
%
% But the code has: 2kM - 1.5k²
%
% DISCREPANCY! The analytical formula doesn't match my derivation!

%% Let's check if the formula accounts for finite lower bound

% Maybe the integral should start at kVals(1), not 0?
%
% Area = ∫_kmin^k 2p dp + ∫_k^M 2k dp  (where kmin = kVals(1))

syms p k M kmin real positive

% Case 1: k > kmin (typical)
Area1 = int(2*p, p, kmin, k) + int(2*k, p, k, M);
Area1 = simplify(Area1)

% This gives: k² - kmin² + 2k(M-k) = k² - kmin² + 2kM - 2k²
%           = 2kM - k² - kmin²

% Still doesn't match! The code has -1.5k², not -k²

%% Check if triad region is truncated at domain boundaries

% For large k, the triad can extend beyond [0, M] × [0, M]
% At p = p0, q ranges from max(k-p0, p0-k, 0) to min(k+p0, M)

% Let's compute the truncated area:
% For p ∈ [0, M-k]: q ∈ [..., k+p]  (no upper truncation)
% For p ∈ [M-k, M]: q ∈ [..., M]    (truncated at M)

% This is getting complex. Let me just write code to check numerically.

fprintf('=== ANALYTICAL FORMULA INVESTIGATION ===\n\n');

% Test with specific values
kVals_test = logspace(log10(0.01), log10(100), 50);
M = max(kVals_test);
kmin = min(kVals_test);

fprintf('Grid: kVals from %.3f to %.3f\n', kmin, M);
fprintf('Number of grid points: %d\n\n', length(kVals_test));

% Test for several k values
test_k_values = [0.01, 0.1, 1, 10, 50, 100];

for k = test_k_values
    % Formula from code
    analytical_code = 2*k*M - 1.5*k^2;

    % My derivation (infinite domain)
    analytical_inf = 2*k*M - k^2;

    % Numerical integration with truncation
    % Integrate over [kmin, M] × [0, M], but only where triad condition satisfied
    num_pts = 1000;
    p_vals = linspace(kmin, M, num_pts);
    area_numerical = 0;

    for i = 1:length(p_vals)-1
        p0 = p_vals(i);
        dp = p_vals(i+1) - p_vals(i);

        % Find q range at this p
        q_lower = max([k-p0, p0-k, 0]);
        q_upper = min([k+p0, M]);

        if q_upper > q_lower
            dq = q_upper - q_lower;
            area_numerical = area_numerical + dq * dp;
        end
    end

    fprintf('k = %.2f:\n', k);
    fprintf('  Code formula:     %.6f\n', analytical_code);
    fprintf('  My derivation:    %.6f\n', analytical_inf);
    fprintf('  Numerical (trunc): %.6f\n', area_numerical);
    fprintf('  Ratio code/num:   %.4f\n', analytical_code/area_numerical);
    fprintf('  Ratio deriv/num:  %.4f\n\n', analytical_inf/area_numerical);
end

%% Check grid cell coverage

fprintf('\n=== GRID CELL COVERAGE ===\n\n');

kLength = length(kVals_test);

% Compute total domain covered by cells
total_cell_coverage = 0;

for pj = 1:kLength
    for qj = 1:kLength
        p = kVals_test(pj);
        q = kVals_test(qj);
        [pM, pP, qM, qP] = getCorners(pj, qj, kLength, p, q, kVals_test);

        cell_area = (pP - pM) * (qP - qM);
        total_cell_coverage = total_cell_coverage + cell_area;
    end
end

theoretical_coverage = (M - kmin)^2;

fprintf('Total area covered by cells: %.6f\n', total_cell_coverage);
fprintf('Theoretical domain area:     %.6f\n', theoretical_coverage);
fprintf('Coverage ratio:              %.6f\n', total_cell_coverage / theoretical_coverage);

% Check boundary cells
fprintf('\n=== BOUNDARY CELL SIZES ===\n\n');

% First cell
pj = 1; qj = 1;
p = kVals_test(pj);
q = kVals_test(qj);
[pM, pP, qM, qP] = getCorners(pj, qj, kLength, p, q, kVals_test);
fprintf('First cell (pj=1, qj=1):\n');
fprintf('  p: [%.6f, %.6f], width = %.6f\n', pM, pP, pP-pM);
fprintf('  q: [%.6f, %.6f], height = %.6f\n', qM, qP, qP-qM);
fprintf('  p value: %.6f\n', p);
fprintf('  q value: %.6f\n\n', q);

% Last cell
pj = kLength; qj = kLength;
p = kVals_test(pj);
q = kVals_test(qj);
[pM, pP, qM, qP] = getCorners(pj, qj, kLength, p, q, kVals_test);
fprintf('Last cell (pj=kLength, qj=kLength):\n');
fprintf('  p: [%.6f, %.6f], width = %.6f\n', pM, pP, pP-pM);
fprintf('  q: [%.6f, %.6f], height = %.6f\n', qM, qP, qP-qM);
fprintf('  p value: %.6f\n', p);
fprintf('  q value: %.6f\n\n', q);

% Middle cell
pj = round(kLength/2); qj = round(kLength/2);
p = kVals_test(pj);
q = kVals_test(qj);
[pM, pP, qM, qP] = getCorners(pj, qj, kLength, p, q, kVals_test);
fprintf('Middle cell (pj=%d, qj=%d):\n', pj, qj);
fprintf('  p: [%.6f, %.6f], width = %.6f\n', pM, pP, pP-pM);
fprintf('  q: [%.6f, %.6f], height = %.6f\n', qM, qP, qP-qM);
fprintf('  p value: %.6f\n', p);
fprintf('  q value: %.6f\n', q);

