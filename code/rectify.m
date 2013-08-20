function S = rectify(s,D,N)
    if(isempty(D))
        D = max(double(s));    
    end

    if(isempty(N))
        N = length(s);
    end

    S = zeros(D,N);
    
    for l=1:length(s)
        x = double(s(l));
        r = x;
        c = 1;
        while r~=0
            if(c==D)
                S(c,l) = r;
                r=0;
            end
            
            if(r>=1)
                S(c,l) = 1;
                r = r-1;
            end
            
            c = c+1;
        end
    end
end
