% Calculates affinity matrix (Linear kernel, RBF)
function [A] = calculateAffinityMatrix(X, affType, p)
    [D,N] = size(X);
    disp(sprintf('Calculating Distance Matrix'));
    
    A = zeros(N,N);
    
    if affType == 1
        fprintf('Using Linear Kernel\n');
        A = X'*X; 
    
    elseif affType == 2
        fprintf('Using Polynomial Kernel with p = %i\n', p);
        A = (X'*X).^p;
%        A = (X'*X+1).^p;
    
    elseif affType == 3
        fprintf('Using RBF Kernel with sigma^2 = %d\n', p);
        R1 = X'*X;
        R2 = ones(N,1) * diag(R1)';
        K  = (1/p)*(R1-0.5*(R2+R2'));
        A  = exp(K);
    
    elseif affType == 4
        fprintf('Using Mahalanobis Kernel\n');

        [D,N] = size(X);

%        X = X';
        
        % Covariance
        mu = mean(X,2);
%        mu = mean(X,2)*ones(1,N);
%        X = X-mu;
%        S = X*X'/(N-1);

        if p == -1
            Si = inv(cov(X'));
        else
            Si = p;
        end

        
        A = zeros(N,N);
        
        for i=1:N
            for j=1:N
%                z = X(:,i) - X(:,j) - 2*mu;
%                A(i,j) = z'*Si*z;
                A(i,j) = (X(:,i)-mu)'*Si*(X(:,j)-mu);
            end
        end
       
    elseif affType == 5
        fprintf('Using SSK with lambda = %i\n', p);
        for i=1:N
            for j=(i-1+1):N
                A(i,j) = SSK(X(:,i)',X(:,j)',p);
                A(j,i) = A(i,j);
            end
        end
        
        fprintf('\n');

    elseif affType == 6
        fprintf('Using SRK\n');
        for i=1:N
            for j=(i-1+1):N
                A(i,j) = SRK(X(:,i)',X(:,j)');
                A(j,i) = A(i,j);
            end
        end
        
        fprintf('\n');
    elseif affType == 7
        fprintf('Using BSRK\n');
        for i=1:N
            for j=(i-1+1):N
                A(i,j) = BRK(X(:,i)',X(:,j)');
                A(j,i) = A(i,j);
            end
        end
        
        fprintf('\n');
    elseif affType == 8
        fprintf('Using BCK\n');
        for i=1:N
            for j=(i-1+1):N
                A(i,j) = BCK(X(:,i)',X(:,j)');
                A(j,i) = A(i,j);
            end
        end
        
        fprintf('\n');
    elseif affType == 9
        fprintf('Using GK\n');
        for i=1:N
            for j=(i-1+1):N
                A(i,j) = GK(X(:,i)',X(:,j)',p);
                A(j,i) = A(i,j);
            end
        end
        
        fprintf('\n');
    end
end