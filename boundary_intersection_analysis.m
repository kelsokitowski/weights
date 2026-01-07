% Analysis: Can multiple boundaries cut the same cell?
%
% For lines 1 and 2 to both cut a cell [pM,pP] x [qM,qP]:
%
% Line 1 (q = k+p) cuts cell if: qM < k+p < qP for some p in [pM,pP]
%   This requires: qM - pP < k < qP - pM
%
% Line 2 (q = k-p) cuts cell if: qM < k-p < qP for some p in [pM,pP]
%   This requires: qM + pP < k < qP + pM
%
% For BOTH to cut the cell simultaneously:
%   max(qM-pP, qM+pP) < k < min(qP-pM, qP+pM)
%   Which simplifies to: qM+pP < k < qP-pM
%
% This requires: qM + pP < qP - pM
%   => qP - qM > pP + pM ≈ 2p (for small cells)
%   => Cell height > 2×p-coordinate
%
% For logarithmically spaced points, this is RARE but POSSIBLE.

% Test with actual kVals
kVals = logspace(log10(0.01), log10(1e5), 100);

multiCutCount = 0;
totalCells = 0;

for kj = 1:length(kVals)
    k = kVals(kj);
    for qj = 1:length(kVals)
        q = kVals(qj);
        for pj = qj:length(kVals)  % Only upper triangle due to symmetry
            p = kVals(pj);

            % Get cell boundaries
            [pM, pP, qM, qP] = getCorners(pj, qj, length(kVals), p, q, kVals);

            totalCells = totalCells + 1;

            % Check if line 1 (q = k+p) cuts this cell
            line1_cuts = (k > qM - pP) && (k < qP - pM);

            % Check if line 2 (q = k-p) cuts this cell
            line2_cuts = (k > qM + pP) && (k < qP + pM);

            % Check if line 3 (q = p-k) cuts this cell
            line3_cuts = (k < pP - qM) && (k > pM - qP);

            numCuts = line1_cuts + line2_cuts + line3_cuts;

            if numCuts > 1
                multiCutCount = multiCutCount + 1;
                if multiCutCount <= 5  % Print first few examples
                    fprintf('Multi-cut cell found: kj=%d, pj=%d, qj=%d\n', kj, pj, qj);
                    fprintf('  k=%.4f, p=%.4f, q=%.4f\n', k, p, q);
                    fprintf('  Cell: [%.4f,%.4f] x [%.4f,%.4f]\n', pM, pP, qM, qP);
                    fprintf('  Lines cutting: ');
                    if line1_cuts, fprintf('1 '); end
                    if line2_cuts, fprintf('2 '); end
                    if line3_cuts, fprintf('3 '); end
                    fprintf('\n\n');
                end
            end
        end
    end
end

fprintf('Summary:\n');
fprintf('Total cells analyzed: %d\n', totalCells);
fprintf('Cells cut by multiple boundaries: %d (%.2f%%)\n', ...
        multiCutCount, 100*multiCutCount/totalCells);
