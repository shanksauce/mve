function plotCompareEigSpectrums(oEigs, mveEigs, figureNum)
    figure(figureNum);
    clf;
    
    numEigs = min(length(mveEigs),5);
    
    if(~isempty(oEigs))
        subplot(2,1,1);
        bar(oEigs(1:5));
        title('Eigenvalues from KPCA', 'FontName', 'Georgia', 'FontWeight', 'bold', 'FontSize', 12);
    
        subplot(2,1,2);
        bar(mveEigs(1:numEigs));
        title('Eigenvalues after MVE', 'FontName', 'Georgia', 'FontWeight', 'bold', 'FontSize', 12);
    else
        bar(mveEigs(1:numEigs));
        title('Eigenvalues from MVE', 'FontName', 'Georgia', 'FontWeight', 'bold', 'FontSize', 12);
    end
    
    axis tight;
end
