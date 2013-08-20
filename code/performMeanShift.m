function performMeanShift(id, kernelsUsed)
    nPtsPerClust = 5;
    nClust  = 3;
    totalNumPts = nPtsPerClust*nClust;
    m(:,1) = [1 1]';
    m(:,2) = [-1 -1]';
    m(:,3) = [1 -1]';

    bandwidth = 0.01;
    sigma = 0.01;
    
    kernelNames = {'SSK','SRK','BSRK','BCK','GK'};
    Y = [];

    for j=kernelsUsed
        Y = [];
        loadString = ['..\Results\SNPs_120610\',num2str(id),'_',kernelNames{j-4},'.mat'];
        load(loadString);
        Y = [Y P{2}(1:2,:)];

        x = Y;

        [clustCent,point2cluster,clustMembsCell] = meanShiftCluster(x, bandwidth, sigma);

        numClust = length(clustMembsCell);

        figure(10+j),clf,hold on;
        plotEmbedding([], Y, [], sprintf('Clustering of %s for Set %i',kernelNames{j-4},id), 10+j, 'k', 1);
       
        cVec = 'bgrcmkybgrcmykbgrcmykbgrcmyk';
        cVec = {[0 0 1], [0 1 0], [1 0 0], [1 0 1], [0 1 1], [0 0.5 1], [0 0.5 0], [0.5 0.5 1], [1 0.5 1], [1 0.75 0.25], [0.75 0 1], [0 0 1], [0 1 0], [1 0 0], [1 0 1], [0 1 1], [0 0.5 1], [0 0.5 0], [0.5 0.5 1], [1 0.5 1], [1 0.75 0.25], [0.75 0 1]};
        
        tt = -pi:0.01:pi;
        for k = 1:numClust
            myMembers = clustMembsCell{k};
            myClustCen = clustCent(:,k);
            plot(myClustCen(1),myClustCen(2),'o','MarkerEdgeColor','k','MarkerFaceColor',cVec{k}, 'MarkerSize',5)
            plot(sqrt(bandwidth)*sin(tt)+myClustCen(1), sqrt(bandwidth)*cos(tt)+myClustCen(2), '--', 'Color', cVec{k})
        end

        axis equal; axis tight;
        maximize(figure(10+j)); set(figure(10+j), 'Position', [0,0,0.38,0.45]);
        saveas(figure(10+j),['..\Results\',num2str(id),'_',kernelNames{j-4},'_Cluster','.pdf']);
    end
end