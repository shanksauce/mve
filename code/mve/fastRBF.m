% fastRBF

function A = fastRBF(X, sigma)


[D,N] = size(X);

A = zeros(N, N);

R1 = X' * X;

Z = diag(R1);

R2 = ones(N, 1) * Z';

R3 = Z * ones(N, 1)';

A  = exp((1/sigma) * R1 - (1/(2*sigma)) * R2 - (1/(2*sigma)) * R3);