function Kout = SSK(s,t,lambda)
   % syms('lambda')
   
    Kpi  = {};
    Kpis = {};
    Kpit = {};
    
    N = 3;
 
    for i=1:(N-1)
        Kpi{i} = Kp(i,s,t,lambda);
    end

    for i=1:(N-1)
        Kpis{i} = Kp(i,s,s,lambda);
    end

    for i=1:(N-1)
        Kpit{i} = Kp(i,t,t,lambda);
    end
    
    Kout = 0;
    Kouts = 0;
    Koutt = 0;
    for n=1:N
        Kouts = Kouts + K(n,s,s,lambda,Kpis);
        Koutt = Koutt + K(n,t,t,lambda,Kpit);
        Kout = Kout + K(n,s,t,lambda,Kpi);
    end
    
    Kout = Kout/sqrt(Kouts*Koutt);
    
    %Kout  = expand(Kout);
    
%    if(isnan(Kout)) Kout = 0; end;
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



function Kout = Kpp(i,s,t,lambda)
    x = s(end);
    tBar = length(t);
    J = find((1:1:tBar).*(x==t) ~= 0);
    
    Kout = 0;
    for j=1:length(J)
        Kout = Kout + Kp(i-1,s(1:end-1),t(1:J(j)-1),lambda) * lambda^(tBar-J(j)+2);
    end
    
    
%    fprintf('Running: %s\n',s(1:end-1));
    
    
end


function Kout = Kp(i,s,t,lambda)
    if(i==0) Kout = 1; return; end;
    if(min(length(s),length(t))<i) Kout = 0; return; end;

    tBar = length(t);
    
    Kout = lambda*Kp(i,s(1:end-1),t,lambda) + Kpp(i,s,t,lambda);
end
