function [clustCent,data2cluster,cluster2dataCell] = meanShiftCluster(dataPts,bandwidth,sigma)
%perform MeanShift Clustering of data using a flat kernel
%
% ---INPUT---
% dataPts           - input data, (numDim x numPts)
% bandWidth         - is bandwidth parameter (scalar)
% plotFlag          - display output if 2 or 3 D    (logical)
% ---OUTPUT---
% clustCent         - is locations of cluster centers (numDim x numClust)
% data2cluster      - for every data point which cluster it belongs to (numPts)
% cluster2dataCell  - for every cluster which points are in it (numClust)
% 
% Bryan Feldman 02/24/06
% MeanShift first appears in
% K. Funkunaga and L.D. Hosteler, "The Estimation of the Gradient of a
% Density Function, with Applications in Pattern Recognition"
%
% Ben Shank 11/16/10: 
% Corrected mean calculation on line 69 to use Gaussian kernel instead of 
% Matlab's mean() function.

%*** Check input ****
plotFlag = false;

%**** Initialize stuff ***
[numDim,numPts] = size(dataPts);
numClust        = 0;

sigmaSq         = sigma^2;
initPtInds      = 1:numPts;
maxPos          = max(dataPts,[],2);                    %biggest size in each dimension
minPos          = min(dataPts,[],2);                    %smallest size in each dimension
boundBox        = maxPos-minPos;                        %bounding box size
sizeSpace       = norm(boundBox);                       %indicator of size of data space
stopThresh      = 1e-3*bandwidth;                       %when mean has converged
clustCent       = [];                                   %center of clust
beenVisitedFlag = zeros(1,numPts,'uint8');              %track if a points been seen already
numInitPts      = numPts;                               %number of points to posibaly use as initilization points
clusterVotes    = zeros(1,numPts,'uint16');             %used to resolve conflicts on cluster membership

if plotFlag
    figure(12345),clf,hold on
end

while numInitPts

    tempInd         = ceil( (numInitPts-1e-6)*rand);        %pick a random seed point
    stInd           = initPtInds(tempInd);                  %use this point as start of mean
    myMean          = dataPts(:,stInd);                     % intilize mean to this points location
    myMembers       = [];                                   % points that will get added to this cluster                          
    thisClusterVotes    = zeros(1,numPts,'uint16');         %used to resolve conflicts on cluster membership

    while 1     %loop untill convergence
        
        sqDistToAll = sum((repmat(myMean,1,numPts) - dataPts).^2);    %dist squared from mean to all points still active
        inInds = find((sqDistToAll < bandwidth));
        thisClusterVotes(inInds) = thisClusterVotes(inInds)+1;  %add a vote for all the in points belonging to this cluster
        myOldMean = myMean;                                   %save the old mean

        % Select the points within the neighborhood
        A = [];
        for j=1:numPts
            if(thisClusterVotes(j)>=1)
                A = [A dataPts(:,j)];
             end
        end
        
        myMean = sum(repmat(gaussianKernel(A,myMean,sigmaSq),size(A,1),1).*A,2)/sum(gaussianKernel(A,myMean,sigmaSq));
        myMembers   = [myMembers inInds];  % Add any point within bandWidth to the cluster
        beenVisitedFlag(myMembers) = 1;    % Mark that these points have been visited
        
        %*** plot stuff ****
        if plotFlag
            tt = -pi:0.01:pi;            
            figure(12345);
            if numDim == 2
                plot(dataPts(1,:),dataPts(2,:),'.')
                plot(dataPts(1,myMembers),dataPts(2,myMembers),'ys')
                plot(myMean(1),myMean(2),'go')
                plot(myOldMean(1),myOldMean(2),'rd')
                plot(sqrt(bandwidth)*sin(tt)+myMean(1), sqrt(bandwidth)*cos(tt)+myMean(2), 'g--')
                axis equal;
                drawnow;
                pause
            end
        end

        %**** if mean doesn't move much stop this cluster ***
        if norm(myMean-myOldMean) < stopThresh
            
            %check for merge posibilities
            mergeWith = 0;
            for cN = 1:numClust
                distToOther = norm(myMean-clustCent(:,cN));     %distance from posible new clust max to old clust max
                if distToOther < bandwidth/2                    %if its within bandwidth/2 merge new and old
                    mergeWith = cN;
                    break;
                end
            end
            
            
            if mergeWith > 0    % something to merge
                clustCent(:,mergeWith)       = 0.5*(myMean+clustCent(:,mergeWith));             %record the max as the mean of the two merged (I know biased twoards new ones)
                %clustMembsCell{mergeWith}    = unique([clustMembsCell{mergeWith} myMembers]);   %record which points inside 
                clusterVotes(mergeWith,:)    = clusterVotes(mergeWith,:) + thisClusterVotes;    %add these votes to the merged cluster
            else    %its a new cluster
                numClust                    = numClust+1;                   %increment clusters
                clustCent(:,numClust)       = myMean;                       %record the mean  
                %clustMembsCell{numClust}    = myMembers;                    %store my members
                clusterVotes(numClust,:)    = thisClusterVotes;
            end

            break;
        end

    end
    
    
    initPtInds      = find(beenVisitedFlag == 0);           %we can initialize with any of the points not yet visited
    numInitPts      = length(initPtInds);                   %number of active points in set

end

[val,data2cluster] = max(clusterVotes,[],1);                %a point belongs to the cluster with the most votes

%*** If they want the cluster2data cell find it for them
if nargout > 2
    cluster2dataCell = cell(numClust,1);
    for cN = 1:numClust
        myMembers = find(data2cluster == cN);
        cluster2dataCell{cN} = myMembers;
    end
end

end


function R = gaussianKernel(X,mu,c)
    B = X-repmat(mu,1,size(X,2));
    R = exp(c * sum(sqrt(B.*B)));
end

