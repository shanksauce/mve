function neighbors = calculateNeighborMatrix(G, bVal, type)
    N = length(G);
        
    if type==1
        fprintf('Finding neighbors using K-nearest with k=%d\n', bVal);
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
        fprintf('Finding neighbors using B-matching -- b=%d\n', bVal);
        neighbors = permutationalBMatch(G, bVal);
        neighbors = neighbors .* (1 - eye(N));
    end
end