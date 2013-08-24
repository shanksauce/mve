function [Y, K, eigVals, mveScore] = mvefull(A, neighbors, tol, targetd)

disp('Using MVE-full');

N = length(A);

% epsilon and slack options
epsNum = (10^-1);
epsilon = epsNum * eye(N, N);
slackVal = 0.1;
maxIter = 20;

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



%set up iteration
M = sdpvar(N, N);
K = A;
K0 = K;
slacks = sdpvar(numConstraints1, 1);

iter = 0;
objRatio = 0;  
objVal0 = 0;



% Iterate
while objRatio < tol && iter < maxIter
    iter = iter + 1;
    disp(sprintf('Optimizing... -- Iteration %d', iter));
    

    F = set(M >= 0);
    
    for k=1:numConstraints1
        i = irow1(k);
        j = icol1(k);
        if i~=j
           F = F + set(M(i, i) + M(j, j) - M(i, j) - M(j, i) == (A(i, i) + A(j, j) - A(i, j) - A(j, i)));
        end
    end
    
    for k=1:numConstraintsG
        i = irowG(k);
        j = icolG(k);
        if i~= j
            F = F + set(M(i, i) + M(j, j) - M(i, j) - M(j, i) >= A(i, i) + A(j, j) - A(i, j) - A(j, i));
        end
    end
    
    F = F + set(sum(sum(M)) == 0);

    F;

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
                       
    K0 = K;

    
    objVal = trace(B' * K);
    
    disp(sprintf('Optimized'));
    disp(sprintf('\tOld cost: %d', objVal0));
    disp(sprintf('\tNew cost: %d', objVal));
    
    objRatio = objVal0/objVal;
    disp(sprintf('Objective ratio %i', objRatio));
    
    
    K0 = K;
    objVal0 = objVal;
    
    
    
end



%Spectral embedding
[Y, eigVals] = eigDecomp(K);

eigNorm = eigVals ./ sum(eigVals);
mveScore = sum(eigNorm(1:targetd));
Y;
eigVals;
K;


function [Y, eigV] = eigDecomp(K)
    [V, D]=eig(K);
    D0 = diag(D);
    V = V * sqrt(D);
    Y=(V(:,end:-1:1))';
    eigV=D0(end:-1:1);
    
    [eigV, IDX] = sort(eigV, 'descend');
    Y = Y(IDX, :);

