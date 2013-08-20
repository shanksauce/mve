function Kout = BCK(s,t)
    
    B = booleanCompare(s,t);
    S = booleanCompare(s,s);
    T = booleanCompare(t,t);
    
    Kout = trace(B'*B)/(norm(S,'fro')*norm(T,'fro'));
    
end

function B = booleanCompare(s,t)
    lS = length(s);
    lT = length(t);
    
%    B = -1*ones(lS,lT);
    B = zeros(lS,lT);
    for i=1:lS
        for j=1:lT
            if(s(i)==t(j))
                B(i,j) = 1;
            end
        end
    end
end

