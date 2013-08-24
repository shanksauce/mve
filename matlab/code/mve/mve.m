% MVE v0.3
%
% Blake Shaw
% Columbia University
% 11/13/06
%
%
% Input:
% A - NxN affinity matrix created by any valid kernel on the original data
% neighbors - NxN binary connectivity matrix
% tol - desired ratio of objective values to determine termination of iteration
% targetd - typically 1 or 2, the target dimension of the embedding
% 
% Output:
% Y - NxN embedding
% K - NxN kernel matrix learned by MVE
% eigvals - N eigenvalues of K
% mveScore - sum of the variance captured in the first targetd dimensions


function [Y, K, eigVals, mveScore] = mve(A, neighbors, tol, targetd)

[D, N] = size(A);

%parameters
params.printlevel=1;
params.maxiter=100;

verbosePlot = 0;
printVals = 0;


G = convertAffinityToDistance(A);

%center
oldA = A;
A = oldA - repmat(sum(A)/N, N, 1) - repmat((sum(A)/N)', 1, N) + sum(sum(A))/(N^2); 
A = (A + A')/2;


%Identify constraints
U = ones(N, N) - neighbors - eye(N);
[irow1, icol1] = find(neighbors==1);
numConstraints1 = length(irow1);

%Identify constraints
[irowG, icolG] = find(U==1);
numConstraintsG = length(irowG);


%set up plots
if verbosePlot
    stats = initializeStats(5, ['Objective Function', 'Trace', 'LogDet', 'Percentage of eigenvalues', 'EigenGap']);
    figureForPlotIters = 12;
    figure(figureForPlotIters);
    clf;
end


%set up iteration
K = A;
K0 = K;
objVal0 = 0;
iter = 0;
objRatio = 0;   


[Y, eigV] = eigDecomp(K);


if verbosePlot==1
    plotEmbeddingIters(Y, neighbors, eigV, N, numIts, 1, figureForPlotIters, verbosePlot);
    stats = computeAndAddStats(stats, K, K0, targetd);
end


% Iterate
while objRatio < tol
    iter = iter + 1;
%    disp(sprintf('Optimizing... -- Iteration %d', iter));
    

    AA = sparse(numConstraints1, N*N);
    bb = zeros(numConstraints1, 1);
    for i=1:numConstraints1
        AA(i, (irow1(i) - 1)*N + irow1(i)) = 1;
        AA(i, (icol1(i) - 1)*N + icol1(i)) = 1;
        AA(i, (irow1(i) - 1)*N + icol1(i)) = -1;
        AA(i, (icol1(i) - 1)*N + irow1(i)) = -1;
        bb(i) = G(irow1(i), icol1(i));
    end
    
    % make all the constraints unique
    [b, m, n] = unique(AA, 'rows');
    A = AA(m, :);
    b = bb(m);
    
    
    % add constraint that points must be centered
    A=[ones(1,N^2);A];
    b=[0;b];
    i=[1;i];
    
    % new objective function
    cc = eye(N);
    
    [v, d] = eig(K);
    B = zeros(N, N);
    for i=1:N-targetd
        B = B + v(:, i) * v(:, i)';
    end
    for i=(N-targetd + 1):N
        B = B - v(:, i) * v(:, i)';
    end
    
    
    c=B';
    
    flags.s=N;
    flags.l=0;
    OPTIONS.maxiter=params.maxiter;
    OPTIONS.printlevel=params.printlevel;
    [x d z info]=csdp(A,b,c,flags,OPTIONS);
    csdpoutput=reshape((x(flags.l+1:flags.l+flags.s^2)), N, N);


    K = csdpoutput;
        
    objVal = trace(B' * K);
    
    disp(sprintf('Optimized'));
%    disp(sprintf('\tOld cost: %d', objVal0));
%    disp(sprintf('\tNew cost: %d', objVal));
    
    objRatio = objVal0/objVal;
%    disp(sprintf('Objective ratio %i', objRatio));
    
    if verbosePlot==1
        [Y, eigV] = eigDecomp(K);
        plotEmbeddingIters(Y, neighbors, eigV, N, numIts, iter, figureForPlotIters, verbosePlot);
        stats = computeAndAddStats(stats, K, K0, targetd);
    end
    
    K0 = K;
    objVal0 = objVal;
end

if verbosePlot
    plotStatsValues(stats, 11, ...
    {'Objective function',...
     'LogDet',...
      'Trace',...
    sprintf('Percentage of eigenvalues captured by first %d eigenvectors', targetd),...
    sprintf('Gap between eigenvalues %d and %d', targetd, targetd+1),...
    },...
     {'r:+', 'r:+', 'r:+', 'r:+', 'r:+', 'r:+'}...
     );
end

%Spectral embedding
[Y, eigVals] = eigDecomp(K);

eigNorm = eigVals ./ sum(eigVals);
mveScore = sum(eigNorm(1:targetd));
%Y;
%eigVals;
%K;


function stats = initializeStats(numPlots, printTitles)
    stats = cell(3, 1);
    stats{1} = numPlots;
    stats{2} = printTitles;
    stats{3} = [];



function stats = computeAndAddStats(stats, K, K0, targetd)

    N = size(K, 1);
    
    [v, d] = eigDecomp(K);
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
        theList = real(plotData(:, i));
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
       
    
function plotEmbeddingIters(Y, neighbors, eigV, N, numIts, iter, figureNum, verbosePlot)
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



function [Y, eigV] = eigDecomp(K)
    [V, D]=eig(K);
    D0 = diag(D);
    V = V * sqrt(D);
    Y=(V(:,end:-1:1))';
    eigV=D0(end:-1:1);
    
    [eigV, IDX] = sort(eigV, 'descend');
    Y = Y(IDX, :);


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
