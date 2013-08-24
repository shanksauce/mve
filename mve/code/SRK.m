function Kout = SRK(s,t)
    %syms('lambda')

    sR = rectify(s,[],[]);
    sT = sR;
%    for n=1:(size(s,2)-1)
%        sT = sT + rotateLeft(sR,n);
%        if(mod(n,2)==0)
%            sT = sT*rotateLeft(sR,n);
%        else
%            sT = sT*rotateLeft(sR,n)';
%        end
%    end
    
    tR = rectify(t,[],[]);
    tT = tR;
%    for n=1:(size(t,2)-1)
%        tT = tT + rotateLeft(tR,n);
%        if(mod(n,2)==0)
%            tT = tT*rotateLeft(tR,n);
%        else
%            tT = tT*rotateLeft(tR,n)';
%        end
%    end
    
    sR = sT;
    tR = tT;
    
    [sD,sN] = size(sT);
    [tD,tN] = size(tT);

    
    D = max(sD,tD);
    N = max(sN,tN);
    
    sFinal = zeros(D,N);
    tFinal = sFinal;
    
    for i=1:D
        for j=1:N
            if(i<=sD && j<=sN) sFinal(i,j) = sR(i,j); end;
            if(i<=tD && j<=tN) tFinal(i,j) = tR(i,j); end;            
        end
    end
    
    sFinal = reshape(sFinal,D*N,1);
    tFinal = reshape(tFinal,D*N,1);
    
    Kout = sFinal'*tFinal/(norm(sFinal)*norm(tFinal));
    
    return
    
    

%% XOR
    

%    Kout = norm(sFinal.*tFinal)/sqrt(norm(sFinal)*norm(tFinal));

    Kout = sum(double(~xor(sFinal,tFinal)))/length(sFinal);
    

    
    
%% Boolean compare
    B = booleanCompare(s,t);
    S = booleanCompare(s,s);
    T = booleanCompare(t,t);
    
    B = reshape(B,size(B,1)*size(B,2),1);
    
    S = reshape(S,length(s)^2,1);
    T = reshape(T,length(t)^2,1);
 
    Kout = B'*B/(norm(S)*norm(T));

    return
    
    
%    Kout = norm(B)/(norm(S) * norm(T))

    %Kout = norm(B,'fro')/(norm(S,'fro') * norm(T,'fro'))
    
%    Kout = sum(sum(B))/( 0.5*(sum(sum(S))+sum(sum(T))) );
    
    return

    
    for n=1:(N-1)
        sR = sR*rotateLeft(s,n)'
        pause
    end
    
    
    sR
    return
    
    [D,N] = size(t);
    sT = t;
    
    for n=1:(N-1)
        sT = sT*rotateLeft(t,n)';
    end
    
    
    
    return
      
    D = max(max(double(s)), max(double(t)));
    N = max(length(s), length(t));
    
    char(rectify(s,D,N)'*rectify(t,D,N));


%    Kout = exp(-norm(rectify(s,D,N) - rectify(t,D,N)))

    
    
    A = rectify(s,D,N)'*rectify(t,D,N);
    
    
    D = min(max(double(s)), max(double(t)));
    char(rectify(s,D,N)'*rectify(t,D,N))
    

    B = rectify(s,D,N)'*rectify(t,D,N);
    
    
    
%    Kout = exp(-norm(A-B));
    
%    Kout = norm(rectify(s,D,N)'*rectify(t,D,N),'fro')/sqrt(norm(rectify(s,D,N)*rectify(s,D,N)','fro') * norm(rectify(t,D,N)*rectify(t,D,N)','fro'));

%    Kout = norm(rectify(s,[],[])*rectify(t,[],[])','fro');

%    Kout = norm(rectify(s,[],[])*rectify(t,[],[])','fro')/sqrt(norm(rectify(s,[],[])*rectify(s,[],[])','fro') * norm(rectify(t,[],[])*rectify(t,[],[])','fro'));
    
    
    return
    
    L = length(s);
    kmin = str2num(char(max(s)));
    
    M = [];
    for k=kmin:25
%        smx = repmat(num2str(k),1,L);
%        M = [M abs(ikadic(s,k) - ikadic(smx,k))];
        smax = 0;
        for l=1:L
            smax = smax + k^(l+1);
        end

        smin = ikadic(repmat(num2str(1),1,L),k);
        
        x = ikadic(s,k);
        
        
        
        M = [M x/smax];
    end
    Kout = M;
   
    
    
    
    
    return
    
    Kpi = {};
    
    N = 3;
 
    for i=1:(N-1)
        Kpi{i} = Kp(i,s,t,lambda);
    end

    Kout = 0;
    for n=1:N
        Kout = Kout + K(n,s,t,lambda,Kpi);%/sqrt(K(n,s,s,lambda,Kpi)*K(n,t,t,lambda,Kpi));
    end
    
%    if(isnan(Kout)) Kout = 0; end;
end





function B = booleanCompare(s,t)
    lS = length(s);
    lT = length(t);
    
    B = zeros(lS,lT);
    for i=1:lS
        for j=1:lT
            B(i,j) = s(i)==t(j);
        end
    end
end



function P = powerset(S)
    

    for i = ( 0:(2^numel(S))-1 )
        
        bitget(i,1:numel(S))
        
    end

    
    P = 0;

    return
    P = cell(size(S)); %Preallocate memory
 
    % Generate all numbers from 0 to 2^(num elements of the set)-1
    for i = ( 0:(2^numel(S))-1 )
        % Convert i into binary, convert each digit in binary to a boolean
        % and store that array of booleans
        indicies = logical(bitget( i,(1:numel(S)) ))
        pause
 
        % Use the array of booleans to extract the members of the original
        % set, and store the set containing these members in the powerset
        P{i+1} = {S(indicies)};
    end
end



function Kout = newK(s,t,A,lambda)
    Kout = computePoly(s,A,lambda)*computePoly(t,A,lambda);
end


function lambdaOut = computePoly(s,A,lambda)
    lambdaOut = 0;    
    for a=1:length(A)
        si = regexp(s,A(a),'start');
        
        if(length(si)==1)
            l = 1;
            lambdaOut = lambda^l;
        elseif(length(si)==2)
            l = si(end)-si(1)+1;
            lambdaOut = lambda^l;
        else
            lmin = si(end-1)-si(1)+1;
            lmax = si(end)-si(1)+1;
            l = (lmax+lmin)/2;
            lambdaOut = lambda^lmax + lambda^lmin;
        end
        
    end
end



function Kout = K(n,s,t,lambda,Kpi)
    if(min(length(s),length(t))<n) Kout = 0; return; end;

    tBar = length(t);
    x = s(end);
    J = find((1:1:tBar).*(x==t) ~= 0);

    sum = 0;

    if(n==1)
        for j=1:length(J)
            sum = sum + lambda^2;
        end
    else
        for j=1:length(J)
            sum = sum + lambda^2 * Kpi{n-1};
        end
    end
    
    Kout = K(n,s(1:end-1),t,lambda,Kpi) + sum;
end




function Kout = Kp(i,s,t,lambda)
    if(i==0) Kout = 1; return; end;
    if(min(length(s),length(t))<i) Kout = 0; return; end;

    tBar = length(t);

    x = s(end);
    J = find((1:1:tBar).*(x==t) ~= 0);
    
    
    sum = 0;
    for j=1:length(J)
        sum = sum + Kp(i-1,s(1:end-1),t(1:J(j)-1),lambda) * lambda^(tBar-J(j)+2);
    end
    
    Kout = lambda*Kp(i,s(1:end-1),t,lambda) + sum;
end
