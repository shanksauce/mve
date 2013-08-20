function clusterResult(Y, bandwidth, sigma)
   
    x = Y(1:2,:);
    [clustCent,point2cluster,clustMembsCell] = meanShiftCluster(x,bandwidth, bandwidth, sigma);

    numClust = length(clustMembsCell);

    figure(10),clf,hold on
    cVec = 'bgrcmykbgrcmykbgrcmykbgrcmyk';%, cVec = [cVec cVec];
    tt = -pi:0.01:pi;
    for k = 1:min(numClust,length(cVec))
        myMembers = clustMembsCell{k};
        myClustCen = clustCent(:,k);
        plot(x(1,myMembers),x(2,myMembers),[cVec(k) '.'])
        plot(myClustCen(1),myClustCen(2), 'o', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', cVec(k), 'MarkerSize',5)
        plot(bandwidth*sin(tt)+myClustCen(1), bandwidth*cos(tt)+myClustCen(2), '--', 'Color', cVec(k))
    end
    title(['no shifting, numClust:' int2str(numClust)]);
    axis equal; 
    %axis tight;
    
end    