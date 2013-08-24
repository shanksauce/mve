function [Y, eigV] = kpca(A)

    N = length(A);
    
    K = A - repmat(sum(A)/N, N, 1) - repmat((sum(A)/N)', 1, N) + sum(sum(A))/(N^2); 
    K = (K + K')/2;
    [V, D]=eig(K);
    D0 = diag(D);
    V = V * sqrt(D);
    Y = (V(:,end:-1:1))';
    eigV = D0(end:-1:1);
    
    [eigV, IDX] = sort(eigV, 'descend');
    Y = Y(IDX, :);
end