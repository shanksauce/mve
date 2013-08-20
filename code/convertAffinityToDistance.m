function G = convertAffinityToDistance(A)
    N = size(A,1);
    G = zeros(N,N);
    
    for i=1:N
        for j=1:N
            G(i,j) = A(i,i) - 2*A(i,j) + A(j,j);
        end
    end 
end
