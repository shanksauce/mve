% MVE driver v0.3
%
% Blake Shaw
% Columbia University
% 11/13/06

%
% An example of using MVE on a simple spiral dataset
%


function mvedriver


%%% parameters
bVal = 3;
targetd = 1;

tol = 0.99;

%%% load data
N = 50;
tt=linspace(0,3*pi,N);
X=[tt.*sin(tt);tt.*cos(tt)];

      
[D, N] = size(X);
disp(sprintf('%d points in %d dimensions:', N, D));


disp(sprintf('Calculating distances...'));
A = calculateAffinityMatrix(X, 1, 5);

A(1:5, 1:5)


G = convertAffinityToDistance(A);
neighbors = calculateNeighborMatrix(G, bVal, 1);


disp(sprintf('Running MVE...'));
[Y, K, eigVals, mveScore] = mve(A, neighbors, tol, targetd);
%[Y, K, eigVals, mveScore] = mveyalmip(A, neighbors, numIts, targetd);
plotEmbedding(Y, neighbors, 'MVE embedding' ,35)

disp(sprintf('Running SDE...'));
[Ysde, K, sdeEigVals, sdeScore] = sde(A, neighbors, targetd);
plotEmbedding(Ysde, neighbors, 'SDE embedding' ,36)

disp(sprintf('Running KPCA...'));
[Ykpca, origEigs] = kpca(A);
plotEmbedding(Ykpca, neighbors, 'KPCA embedding' ,37)

plotCompareEigSpectrums(origEigs, eigVals, 3);


save results.mat;

%
% Auxiliary Functions
%


% Calculates affinity matrix (Linear kernel, RBF)
function [A] = calculateAffinityMatrix(X, affType, sigma)
    [D,N] = size(X);
    disp(sprintf('Calculating Distance Matrix'));
    
    A = zeros(N, N);
    
    if affType == 1
        disp(sprintf('Using Linear Kernel'));
        A = X' * X; 
        %A = cov(X);
    elseif affType == 2
        disp(sprintf('Using RBF Kernel'));
        A = zeros(N, N);
        R1 = X' * X;
        Z = diag(R1);
        R2 = ones(N, 1) * Z';
        R3 = Z * ones(N, 1)';
        A  = exp((1/sigma) * R1 - (1/(2*sigma)) * R2 - (1/(2*sigma)) * R3);
    end



% Finds nearest neighbors in distance matrix G
function neighbors = calculateNeighborMatrix(G, bVal, type)

    N=length(G);
        
    if type==1
        disp(sprintf('Finding neighbors using K-nearest -- k=%d', bVal));
        [sorted,index] = sort(G);
        nearestNeighbors = index(2:(bVal+1),:);
        
        
        neighbors = zeros(N, N);
        for i=1:N
            for j=1:bVal
                neighbors(i, nearestNeighbors(j, i)) = 1;
                neighbors(nearestNeighbors(j, i), i) = 1;
            end
        end
        
    else
        disp(sprintf('Finding neighbors using B-matching -- b=%d', bVal));
        neighbors = permutationalBMatch(G, bVal);
        neighbors = neighbors .* (1 - eye(N));
    end


% Converts and affinity matrix to a distance matrix
function G = convertAffinityToDistance(A)
    N = size(A, 1);
    G = zeros(N, N);
    
    for i=1:N
        for j=1:N
            G(i, j) = A(i, i) - 2*A(i, j) + A(j, j);
        end
    end 

% Creates a plot comparing two eigenvalue spectrums
function plotCompareEigSpectrums(oEigs, mveEigs, figureNum);
    figure(figureNum);
    clf;
    subplot(2,1,1);
    bar(oEigs);
    title('Original Eigenvalues');
    subplot(2,1,2);
    bar(mveEigs);
    title('Eigenvalues after MVE');


% Plots a 2d embedding
function plotEmbedding(Y, neighbors, plotTitle, figureNum)
    figure(figureNum);
    clf;
    
    N = length(neighbors);
    
    scatter(Y(1,:),Y(2,:), 60,'filled'); axis equal;
    for i=1:N
        for j=1:N
            if neighbors(i, j) == 1
                line( [Y(1, i), Y(1, j)], [ Y(2, i), Y(2, j)], 'Color', [0, 0, 1], 'LineWidth', 1);
            end
        end
    end
    
    title(plotTitle);
    drawnow; 
    axis off;

% Performs kernel principal component analysis
function [Y, eigV] = kpca(A);

    N = length(A);
    
    K = A - repmat(sum(A)/N, N, 1) - repmat((sum(A)/N)', 1, N) + sum(sum(A))/(N^2); K = (K + K')/2;
    [V, D]=eig(K);
    D0 = diag(D);
    V = V * sqrt(D);
    Y=(V(:,end:-1:1))';
    eigV=D0(end:-1:1);
    
    [eigV, IDX] = sort(eigV, 'descend');
    Y = Y(IDX, :);
    

