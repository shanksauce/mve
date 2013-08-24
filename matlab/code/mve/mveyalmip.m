% MVE v0.1
%
% Yalmip version
%
% Blake Shaw
% Columbia University
% 11/13/06


function [Y, K, eigVals, mveScore] = mveyalmip(A, neighbors, numIts, targetd)

[D, N] = size(A);

%parameters
params.printlevel=1;
params.maxiter=100;

G = convertAffinityToDistance(A);

%center
oldA = A;
A = oldA - repmat(sum(A)/N, N, 1) - repmat((sum(A)/N)', 1, N) + sum(sum(A))/(N^2);


%Identify constraints
U = ones(N, N) - neighbors - eye(N);
[irow1, icol1] = find(neighbors==1);
numConstraints1 = length(irow1);

%Identify constraints
[irowG, icolG] = find(U==1);
numConstraintsG = length(irowG);


%set up plots
stats = initializeStats(5, ['Objective Function', 'Trace', 'LogDet', 'Percentage of eigenvalues', 'EigenGap']);
figureForPlotIters = 12;
figure(figureForPlotIters);
clf;


%set up iteration
K = A;
K0 = K;
M = sdpvar(N, N);


[Y, eigV] = eigDecomp(K);
plotEmbeddingIters(Y, neighbors, eigV, N, numIts, 1, figureForPlotIters);


%Get stats
stats = computeAndAddStats(stats, K, K0, targetd);

% Iterate
for iter=2:numIts
    disp(sprintf('Optimizing... -- Iteration %d', iter));

 F = set(M >= 0);
    
    for k=1:numConstraints1
        i = irow1(k);
        j = icol1(k);
        if i~=j
            F = F + set(M(i, i) + M(j, j) - M(i, j) - M(j, i) == (A(i, i) + A(j, j) - A(i, j) - A(j, i)));
        end
    end

    F = F + set(sum(sum(M)) == 0);

    [v, d] = eig(K);
    B = zeros(N, N);
    for i=1:N-targetd
        B = B + v(:, i) * v(:, i)';
    end
    for i=(N-targetd + 1):N
        B = B - v(:, i) * v(:, i)';
    end
    
    sol = solvesdp(F, trace(B' * M), sdpsettings('solver', 'csdp', 'cachesolvers', 1));

    if(sol.problem == 2)
        break;
    end
    
    K = double(M);
                     

    %Get stats
    stats = computeAndAddStats(stats, K, K0, targetd);
    
    
    %EigenDecompose and plot status
    [Y, eigV] = eigDecomp(K, 0);
    plotEmbeddingIters(Y, neighbors, eigV, N, numIts, iter, figureForPlotIters);
    
    
    K0 = K;
end

plotStatsValues(stats, 11, ...
{'Objective function',...
 'LogDet',...
  'Trace',...
sprintf('Percentage of eigenvalues captured by first %d eigenvectors', targetd),...
sprintf('Gap between eigenvalues %d and %d', targetd, targetd+1),...
},...
 {'r:+', 'r:+', 'r:+', 'r:+', 'r:+', 'r:+'}...
 );

%Spectral embedding
[Y, eigVals] = eigDecomp(K);

eigNorm = eigVals ./ sum(eigVals);
mveScore = sum(eigNorm(1:targetd));
Y;
eigVals;
K;


function stats = initializeStats(numPlots, printTitles)
    stats = cell(3, 1);
    stats{1} = numPlots;
    stats{2} = printTitles;
    stats{3} = [];



function stats = computeAndAddStats(stats, K, K0, targetd)

    N = size(K, 1);
    
    [v, d] = eig(K);
    B = zeros(N, N);
    for i=1:N-targetd
        B = B + v(:, i) * v(:, i)';
    end
    for i=(N-targetd + 1):N
        B = B - v(:, i) * v(:, i)';
    end
    
    
    Ke = K + 10^-5;
    [Y, eigV] = eigDecomp(K);
    eigNorm = eigV ./ sum(eigV);
    eigScore = sum(eigNorm(1:targetd));
    eigGap = eigNorm(targetd) - eigNorm(targetd+1);
    
     
    objVal = trace(B' * K);
    objVal2 = logdet2(Ke);
    objVal3 = trace(K);
    
    dd = diag(d);
    objValTrue = sum(dd(1:N-targetd)) - sum(dd((N-targetd+1):N));
    
    
    stats = addStatsValues(stats, [objVal, objVal2, objVal3, eigScore, eigGap], 1);

function stats = addStatsValues(stats, newVals, printVals)
    stats{3} = [stats{3}; newVals];
    if printVals == 1
        stats{3}
    end

function plotStatsValues(stats, figureNum, plotTitles, markerStyle)
    figure(figureNum);
    clf;
    numPlots = stats{1};
    plotData = stats{3};
    
    for i=1:numPlots
        subplot(numPlots, 1, i);
        theList = plotData(:, i);
        plot(1:length(theList), theList, markerStyle{i});
        title(plotTitles{i});
    end
    
    figure(76);
    
    plotData1 = (plotData(:, 1)- min(plotData(:, 1)))/(max(plotData(:, 1)) - min(plotData(:, 1)));
    plotData2 = (plotData(:, 2)- min(plotData(:, 2)))/(max(plotData(:, 2)) - min(plotData(:, 2)));
    plotData3 = (plotData(:, 3)- min(plotData(:, 3)))/(max(plotData(:, 3)) - min(plotData(:, 3)));
    clf;
    hold on;
    plot(1:length(theList), plotData1, '-r+', 'LineWidth', 2);
    plot(1:length(theList), plotData2, '-bx', 'LineWidth', 2);
    plot(1:length(theList), plotData3, '-g*', 'LineWidth', 2); 
    hold off; 
    
    legend('Cost(K)', 'LogDet(K)', 'Tr(K)');
       
    
function plotEmbeddingIters(Y, neighbors, eigV, N, numIts, iter, figureNum);
    
    edgeWeights = ones(N, N);  
    figure(figureNum);
    subplot(2, numIts, iter);
    scatter(Y(1,:),Y(2,:), 50, 'filled'); axis equal;
    
    Y = real(Y);
    for i=1:N
        for j=1:N
            if neighbors(i, j) == 1
                line( [Y(1, i), Y(1, j)], [Y(2, i), Y(2, j)], 'Color', [0, 0, 1], 'LineWidth', edgeWeights(i, j) + 0.1);
            end
        end
    end
    axis equal;
    drawnow;
    
    figure(figureNum);
    subplot(2, numIts, iter+numIts);
    %bar(log(eigV + epsNum));
    bar(eigV);
    
    drawnow;



function [Y, eigV] = eigDecomp(K, swap)
    [V, D]=eig(K);
    D0 = diag(D);
    V = V * sqrt(D);
    Y=(V(:,end:-1:1))';
    eigV=D0(end:-1:1);


function x = logdet2(K)
    [V, D]=eig(K);
    D0 = diag(D);
    x = sum(log(D0));

function G = convertAffinityToDistance(A)
    N = size(A, 1);
    G = zeros(N, N);
    
    for i=1:N
        for j=1:N
            G(i, j) = A(i, i) - 2*A(i, j) + A(j, j);
        end
    end 
