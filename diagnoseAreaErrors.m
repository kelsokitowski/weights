function diagnoseAreaErrors(kVals)
% DIAGNOSEAREAERRORS - Diagnostic tool to identify where area calculation errors occur
%
% This script is designed to be inserted into midpoint2dShoelace.m to collect
% detailed information about when and where the two area calculation methods
% (subtraction method vs. shoelace method) disagree.
%
% Usage: Call this function when an area discrepancy is detected
%
% Inputs:
%   kVals - vector of k values (logarithmically spaced)
%
% The function will create diagnostic output files and plots showing:
%   1. Distribution of errors vs k value
%   2. Correlation between number of active cuts and error magnitude
%   3. Inside vs outside cell error patterns

% Initialize error tracking arrays
global ERROR_LOG;
if isempty(ERROR_LOG)
    ERROR_LOG = struct('pj', [], 'qj', [], 'kj', [], ...
                       'p', [], 'q', [], 'k', [], ...
                       'areas', [], 'areas2', [], 'error', [], ...
                       'flag1', [], 'flag2', [], 'flag3', [], ...
                       'numFlags', [], 'isOutside', [], ...
                       'cellWidth', [], 'cellHeight', []);
end

fprintf('\n=== AREA ERROR DIAGNOSTICS ===\n');
fprintf('This diagnostic mode will track all area calculation discrepancies\n\n');

end

function logError(pj, qj, kj, p, q, k, areas_val, areas2_val, flag1, flag2, flag3, outsideFlag, pM, pP, qM, qP)
% LOGERROR - Log a single error occurrence
%
% Insert this function call in midpoint2dShoelace.m at line 149 when error detected

global ERROR_LOG;

idx = length(ERROR_LOG.pj) + 1;
ERROR_LOG.pj(idx) = pj;
ERROR_LOG.qj(idx) = qj;
ERROR_LOG.kj(idx) = kj;
ERROR_LOG.p(idx) = p;
ERROR_LOG.q(idx) = q;
ERROR_LOG.k(idx) = k;
ERROR_LOG.areas(idx) = areas_val;
ERROR_LOG.areas2(idx) = areas2_val;
ERROR_LOG.error(idx) = abs(abs(areas2_val) - abs(areas_val));
ERROR_LOG.flag1(idx) = flag1;
ERROR_LOG.flag2(idx) = flag2;
ERROR_LOG.flag3(idx) = flag3;
ERROR_LOG.numFlags(idx) = flag1 + flag2 + flag3;
ERROR_LOG.isOutside(idx) = outsideFlag;
ERROR_LOG.cellWidth(idx) = pP - pM;
ERROR_LOG.cellHeight(idx) = qP - qM;

end

function analyzeErrors()
% ANALYZEAERRORS - Analyze collected error data and generate report
%
% Call this function at the end of midpoint2dShoelace.m after all calculations

global ERROR_LOG;

if isempty(ERROR_LOG.pj)
    fprintf('No errors detected!\n');
    return;
end

numErrors = length(ERROR_LOG.pj);
fprintf('\n=== ERROR ANALYSIS REPORT ===\n');
fprintf('Total number of errors: %d\n\n', numErrors);

% 1. Error distribution by number of active cuts
fprintf('1. ERRORS BY NUMBER OF ACTIVE BOUNDARIES:\n');
for nf = 0:3
    count = sum(ERROR_LOG.numFlags == nf);
    if count > 0
        avgError = mean(ERROR_LOG.error(ERROR_LOG.numFlags == nf));
        maxError = max(ERROR_LOG.error(ERROR_LOG.numFlags == nf));
        fprintf('   %d boundaries: %d errors (%.1f%%), avg error=%.2e, max error=%.2e\n', ...
                nf, count, 100*count/numErrors, avgError, maxError);
    end
end

% 2. Error distribution by inside/outside status
fprintf('\n2. ERRORS BY CELL LOCATION:\n');
insideErrors = sum(ERROR_LOG.isOutside == 0);
outsideErrors = sum(ERROR_LOG.isOutside == 1);
fprintf('   Inside triad: %d errors (%.1f%%)\n', insideErrors, 100*insideErrors/numErrors);
fprintf('   Outside triad (cut): %d errors (%.1f%%)\n', outsideErrors, 100*outsideErrors/numErrors);

% 3. Error distribution by k value
fprintf('\n3. ERRORS BY K VALUE RANGE:\n');
kUnique = unique(ERROR_LOG.k);
kRanges = [min(kUnique), 0.1, 1, 10, 100, 1000, max(kUnique)];
for i = 1:length(kRanges)-1
    inRange = (ERROR_LOG.k >= kRanges(i)) & (ERROR_LOG.k < kRanges(i+1));
    count = sum(inRange);
    if count > 0
        avgError = mean(ERROR_LOG.error(inRange));
        fprintf('   k ∈ [%.2e, %.2e): %d errors, avg error=%.2e\n', ...
                kRanges(i), kRanges(i+1), count, avgError);
    end
end

% 4. Largest errors
fprintf('\n4. TOP 10 LARGEST ERRORS:\n');
[sortedErrors, sortIdx] = sort(ERROR_LOG.error, 'descend');
numShow = min(10, numErrors);
for i = 1:numShow
    idx = sortIdx(i);
    fprintf('   #%d: kj=%d, pj=%d, qj=%d | k=%.3e, p=%.3e, q=%.3e\n', ...
            i, ERROR_LOG.kj(idx), ERROR_LOG.pj(idx), ERROR_LOG.qj(idx), ...
            ERROR_LOG.k(idx), ERROR_LOG.p(idx), ERROR_LOG.q(idx));
    fprintf('       areas=%.6e, areas2=%.6e, error=%.6e\n', ...
            ERROR_LOG.areas(idx), ERROR_LOG.areas2(idx), ERROR_LOG.error(idx));
    fprintf('       flags=[%d,%d,%d], outside=%d, cellSize=[%.3e × %.3e]\n', ...
            ERROR_LOG.flag1(idx), ERROR_LOG.flag2(idx), ERROR_LOG.flag3(idx), ...
            ERROR_LOG.isOutside(idx), ERROR_LOG.cellWidth(idx), ERROR_LOG.cellHeight(idx));
end

% 5. Create diagnostic plots
figure('Position', [100, 100, 1200, 800]);

% Plot 1: Error vs k value
subplot(2,3,1);
loglog(ERROR_LOG.k, ERROR_LOG.error, 'b.', 'MarkerSize', 8);
xlabel('k value');
ylabel('Absolute Error |areas2 - areas|');
title('Error vs k Value');
grid on;

% Plot 2: Error vs number of cuts
subplot(2,3,2);
boxplot(ERROR_LOG.error, ERROR_LOG.numFlags);
xlabel('Number of Active Boundary Cuts');
ylabel('Absolute Error');
title('Error vs Number of Cuts');
set(gca, 'YScale', 'log');

% Plot 3: Error vs cell size
subplot(2,3,3);
cellArea = ERROR_LOG.cellWidth .* ERROR_LOG.cellHeight;
loglog(cellArea, ERROR_LOG.error, 'r.', 'MarkerSize', 8);
xlabel('Cell Area');
ylabel('Absolute Error');
title('Error vs Cell Area');
grid on;

% Plot 4: Relative error distribution
subplot(2,3,4);
relError = ERROR_LOG.error ./ max(abs(ERROR_LOG.areas), abs(ERROR_LOG.areas2));
histogram(log10(relError), 30);
xlabel('log_{10}(Relative Error)');
ylabel('Count');
title('Relative Error Distribution');

% Plot 5: Error by position in p-q space
subplot(2,3,5);
scatter(ERROR_LOG.p, ERROR_LOG.q, 50, log10(ERROR_LOG.error), 'filled');
xlabel('p value');
ylabel('q value');
title('Error Location in p-q Plane');
colorbar;
set(gca, 'XScale', 'log', 'YScale', 'log');

% Plot 6: Inside vs outside comparison
subplot(2,3,6);
insideErrors = ERROR_LOG.error(ERROR_LOG.isOutside == 0);
outsideErrors = ERROR_LOG.error(ERROR_LOG.isOutside == 1);
if ~isempty(insideErrors) && ~isempty(outsideErrors)
    histogram(log10(insideErrors), 20, 'FaceAlpha', 0.5, 'DisplayName', 'Inside Triad');
    hold on;
    histogram(log10(outsideErrors), 20, 'FaceAlpha', 0.5, 'DisplayName', 'Outside Triad (cut)');
    xlabel('log_{10}(Error)');
    ylabel('Count');
    title('Inside vs Outside Cell Errors');
    legend;
end

sgtitle(sprintf('Area Error Diagnostics (%d total errors)', numErrors));

% Save the figure
saveas(gcf, 'area_error_diagnostics.png');
fprintf('\n5. Diagnostic plots saved to: area_error_diagnostics.png\n');

% Save error log to file
save('area_error_log.mat', 'ERROR_LOG');
fprintf('6. Error data saved to: area_error_log.mat\n');

% 6. Statistical summary
fprintf('\n7. STATISTICAL SUMMARY:\n');
fprintf('   Mean error: %.6e\n', mean(ERROR_LOG.error));
fprintf('   Median error: %.6e\n', median(ERROR_LOG.error));
fprintf('   Std dev: %.6e\n', std(ERROR_LOG.error));
fprintf('   Max error: %.6e\n', max(ERROR_LOG.error));
fprintf('   Min error: %.6e\n', min(ERROR_LOG.error));

% 7. Hypothesis testing
fprintf('\n8. HYPOTHESIS TESTS:\n');

% Test: Do multiple cuts cause more errors?
singleCut = ERROR_LOG.error(ERROR_LOG.numFlags == 1);
multiCut = ERROR_LOG.error(ERROR_LOG.numFlags > 1);
if ~isempty(singleCut) && ~isempty(multiCut)
    [~, pval] = ttest2(singleCut, multiCut);
    fprintf('   Multiple cuts vs single cut: p-value = %.4f\n', pval);
    if pval < 0.05
        fprintf('   → SIGNIFICANT: Multiple cuts lead to different error magnitudes\n');
    else
        fprintf('   → Not significant\n');
    end
end

% Test: Do outside cells have more errors?
insideErrs = ERROR_LOG.error(ERROR_LOG.isOutside == 0);
outsideErrs = ERROR_LOG.error(ERROR_LOG.isOutside == 1);
if ~isempty(insideErrs) && ~isempty(outsideErrs)
    [~, pval] = ttest2(insideErrs, outsideErrs);
    fprintf('   Outside vs inside cells: p-value = %.4f\n', pval);
    if pval < 0.05
        fprintf('   → SIGNIFICANT: Outside cells have different error magnitudes\n');
    else
        fprintf('   → Not significant\n');
    end
end

fprintf('\n=== END OF ERROR ANALYSIS ===\n\n');

end

%% INSTRUCTIONS FOR INTEGRATION
%
% To use this diagnostic tool, modify midpoint2dShoelace.m as follows:
%
% 1. At the beginning of midpoint2dShoelace.m (after line 1), add:
%    global ERROR_LOG;
%    ERROR_LOG = struct('pj', [], 'qj', [], 'kj', [], 'p', [], 'q', [], 'k', [], ...
%                       'areas', [], 'areas2', [], 'error', [], 'flag1', [], 'flag2', [], ...
%                       'flag3', [], 'numFlags', [], 'isOutside', [], ...
%                       'cellWidth', [], 'cellHeight', []);
%
% 2. Replace the error reporting block (lines 149-157) with:
%    if abs(abs(areas2(pj,qj,kj))-abs(areas(pj,qj,kj))) > 1.0e-04
%        logError(pj, qj, kj, p, q, k, areas(pj,qj,kj), areas2(pj,qj,kj), ...
%                 flag1, flag2, flag3, outsideCutCell(pj,qj,kj), pM, pP, qM, qP);
%        disp('uhoh areas2(pj,qj,kj) neq areas(pj,qj,kj) :144 midpoint2dShoelace')
%        fprintf('pj=%i,qj=%i,kj=%i ',pj,qj,kj)
%        fprintf('flag1=%i flag2=%i flag3=%i \n',flag1,flag2,flag3)
%        fprintf('areas2(pj,qj,kj)=%f,areas(pj,qj,kj)=%f',areas2(pj,qj,kj),areas(pj,qj,kj))
%        a2MinusA = abs(abs(areas2(pj,qj,kj))-abs(areas(pj,qj,kj)));
%        fprintf('outsideCutCell(pj,qj,kj)=%i, a2-A=%f \n',outsideCutCell(pj,qj,kj),a2MinusA)
%    end
%
% 3. At the end of midpoint2dShoelace.m (before the final 'end'), add:
%    analyzeErrors();
%
% 4. Run midpoint2dShoelace with your kVals vector
%
% The diagnostic will generate:
%   - Detailed console output about error patterns
%   - area_error_diagnostics.png with 6 diagnostic plots
%   - area_error_log.mat with all error data for further analysis
