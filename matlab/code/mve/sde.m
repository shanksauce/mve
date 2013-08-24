function [Y, K, eigVals, sdeScore] = sde(A, neighbors, targetd)

% Calculate constraints
N = length(A);

G = convertAffinityToDistance(A);

params.printlevel=1;
params.maxiter=100;

%distances = Bn;
[irow1, icol1] = find(neighbors==1);
numConstraints1 = length(irow1);

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
    c=0-cc(:);
    
    
    flags.s=N;
    flags.l=0;
    OPTIONS.maxiter=params.maxiter;
    OPTIONS.printlevel=params.printlevel;
    [x d z info]=csdp(A,b,c,flags,OPTIONS);
    csdpoutput=reshape((x(flags.l+1:flags.l+flags.s^2)), N, N);


    K = csdpoutput;

%K = inv(sol);
objVal = 0;

%spectral embedding
[V, D]=eig(K);
D0 = diag(D);
V = V * sqrt(D);
Y=(V(:,end:-1:1))';
eigVals=D0(end:-1:1);
eigNorm = eigVals ./ sum(eigVals);
sdeScore = sum(eigNorm(1:targetd));


function G = convertAffinityToDistance(A)
    N = size(A, 1);
    G = zeros(N, N);
    
    for i=1:N
        for j=1:N
            G(i, j) = A(i, i) - 2*A(i, j) + A(j, j);
        end
    end 
    
    
