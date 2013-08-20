function plotEmbedding(X, Y, neighbors, plotTitle, figureNum, color, plotText)
    figure(figureNum);
   
    strains = {'DBA/2J', 'A/J', 'BALB/cByJ', 'C3H/HeJ', 'AKR/J', 'FVB/NJ', '129S1/SvImJ', 'NOD/LtJ', 'WSB/EiJ', 'PWD/PhJ', 'BTBR T+ tf/J', 'CAST/EiJ', 'MOLF/EiJ', 'NZW/LacJ', 'KK/HlJ'};
    
    N = length(Y);
    
    sc = max(max(Y(2,:)));
    
    hold on;
    scatter(Y(1,:), Y(2,:), 10, 'filled', 'MarkerFaceColor', color); 

    H = [];
    
%    for i=1:N
%        text(Y(1,i), 0.001+Y(2,i), sprintf(strcat(strains{i},': (%i)'),i));
        
        if(plotText == 1)
            
            figure(figureNum);
            C = get(gca, 'Children');
            L = [];
            
            for c=1:length(C)
                if(strcmp(get(C(c),'Type'),'text'))
                    P = get(C(c),'Position');
                    if(P(3)<1)
                        L = [L C(c)];
                    end
                end
            end
            
            
            if(isempty(L))
%{
                H = [];
                for i=1:N
                    if(i==1)
                        H = [H text(rand*0.01 + Y(1,i), rand*0.01 + Y(2,i), sprintf('(%i)',i), 'FontName', 'Times', 'FontWeight', 'bold', 'FontSize', 12, 'Color', color)];
                    else
                        P = [];
                        for j=1:length(H)
                            P = [P; get(H(j),'Position')];
                        end
                        
                        H = [H text(Y(1,i), rand*0.1 + Y(2,i), sprintf('(%i)',i), 'FontName', 'Times', 'FontWeight', 'bold', 'FontSize', 12, 'Color', color)];

                        thisP = get(H(end),'Position');

                        for j=1:(length(H)-1)
                            Xtent = get(gca, 'XLim');
                            Ytent = get(gca, 'YLim');

                            while( norm(P(j,:)-thisP) < 0.08 || thisP(1) < Xtent(1) || thisP(2) > Xtent(2) || thisP(1) < Ytent(1) || thisP(2) > Ytent(2) )
                                r = 0.08*rand;
                                s1 = real((-1)^(round(rand)));
                                s2 = real((-1)^(round(rand)));
                                
                                set(H(end), 'Position', [Y(1,i), Y(2,i)+(s2*r), 0]);
                                thisP = get(H(end),'Position');
                                drawnow
                            end
                        end
                        
                        plot([Y(1,i) thisP(1)], [Y(2,i) thisP(2)], 'k--')
                        
                    end
                end
            else
%}                
                H = [];
                for i=1:N
                    
                    P = [];
                    for j=1:length(L)
                        P = [P; get(L(j),'Position')];
                    end
                    
                    L = [L text(rand*0.01 + Y(1,i), rand*0.01 + Y(2,i), sprintf('(%i)',i), 'FontName', 'Times', 'FontWeight', 'bold', 'FontSize', 12, 'Color', color)];
                    thisP = get(L(end),'Position');

                    if(~isempty(P))
                        PStar = P-repmat(thisP, size(P,1), 1);
                        relabel = find( (1:1:size(PStar,1))' .* (sum(PStar.*PStar,2)<0.006));

                        thisPOrig = thisP;
                        itr = 0;

                        Ytent = get(gca, 'YLim');


                        while(~isempty(relabel))
                            if( thisP(2) < Ytent(1) )
                                s = 1;
                            else
                                s = -1;
                            end

                            if(itr > 100)
                                set(L(end), 'Position', thisPOrig+[0.1*s,0.1*s,0]);
                                itr = 0;
                            else
                                set(L(end), 'Position', thisP+[0, 0.01*s,0]);
                            end

                            thisP = get(L(end),'Position');
                            PStar = P-repmat(thisP, size(P,1), 1);
                            relabel = find( (1:1:size(PStar,1))' .* (sum(PStar.*PStar,2)<0.006));
                            itr = itr+1;
                        
                            drawnow;
                        end
                        
                    end
                    
                    plot([Y(1,i) thisP(1)], [Y(2,i) thisP(2)], 'Color', [0.7 0.7 0.7])
                    
                end
                
                
            end
            
            
        end
%    end

%        for j=1:N
%            if neighbors(i, j) == 1
%                line( [Y(1,i), Y(1,j)], [ Y(2,i), Y(2,j)], 'Color', [0,0,1], 'LineWidth', 0.35, 'LineStyle', '-.');
%            end
%        end
        
    
    title(plotTitle, 'FontName', 'Times', 'FontWeight', 'bold', 'FontSize', 12);
    drawnow; 
end
