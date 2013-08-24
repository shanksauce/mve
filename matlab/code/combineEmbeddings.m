function combineEmbeddings(id)
    colors = ['k', 'r', 'b', 'g', 'm'];
    kernelNames = {'SSK','SRK','BSRK','BCK'};
    
    for j=1:(length(kernelNames)-1)
        loadString = ['..\Results\',num2str(id),'_',kernelNames{j},'.mat'];
        load(loadString);
        plotEmbedding([], P{2}, [], 'Combined MVE Embeddings', 335, colors(j), 1);
    end

    maximize(figure(335)); set(figure(335), 'Position', [0,0,0.38,0.45]);
    legend('SSK','SRK','BSRK','Location','Best');
    saveas(figure(335),['..\Results\','Combined_',num2str(id),'.pdf']);    
end