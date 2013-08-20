function performMVE
    clc; close all; clear all;

    homeDir = 'D:\Junk\School\Columbia\COMS4772\';
    
    path([homeDir,'mve'],path);
    path([homeDir,'netlab'],path);
    path([homeDir,'Spectral Clustering\SPECTRAL0p1'],path);
    path([homeDir,'csdp6.1.0winp4\bin'],path);
    path([homeDir,'csdp6.1.0winp4\matlab'],path);
    path([homeDir,'yalmip'],path);
    path([homeDir,'yalmip\extras'],path);
    path([homeDir,'yalmip\solvers'],path);
    path([homeDir,'yalmip\operators'],path);
    path([homeDir,'yalmip\modules\global'],path);
    path([homeDir,'yalmip\modules\moment'],path);
    path([homeDir,'yalmip\modules\parametric'],path);
    path([homeDir,'yalmip\modules\robust'],path);
    path([homeDir,'yalmip\modules\sos'],path);

    % For SSK
    set(0,'RecursionLimit',1000);
    
    % SNP Datasets
    %   1 - 139
    %   2 - 39
    %   3 - 15
    %   4 - 873
    %   5 - 186
    %   6 - 1
    %   7 - 6
    %   8 - 14
   
    % Kernels
    %   5 = SSK
    %   6 = SRK
    %   7 = BSRK
    %   8 = BCK

    kernelsUsed = [6];

    for j=[2] % Which data sets?
        for kernelType = kernelsUsed
            targetd = 2;
            tol = 0.99;
            scaleFactor = 1;
            color = ['k', 'r', 'b', 'g', 'm'];
            kernelNames = {'SSK','SRK','BSRK','BCK','GK'};

            load('SubsetSNPsChr01.mat');
            numHapBlocks = length(sub);
            X = cell2mat(sub{j}.SNPs);

            % Sort input strings for convenience
            if(size(X,1)>1)
                B = sum(X);
                [Y,I] = sort(B);
                X = X(:,I);
            else
                sort(X);
            end

            [D,N] = size(X);
            fprintf('%d points in %d dimensions:\n', N, D);

            lambda = 0.25;

            A = calculateAffinityMatrix(X, kernelType, lambda);
            G = convertAffinityToDistance(A);
            
            kVal = 8;
            neighbors = calculateNeighborMatrix(G, kVal, 1);

            [Y, K, eigVals, mveScore] = mvefull(A, neighbors, tol, targetd);

    %        Ys = Y.* repmat(eigVals,1,size(Y,2));
            Ys = Y/max(max(Y));

            P = {};
            P{1} = X;
            P{2} = Ys;
            P{3} = eigVals;
            save(strcat('..\Results\',num2str(j),'_',kernelNames{kernelType-4},'.mat'),'P');

            clear A D G K N P Y Ys eigVals kVal lambda mveScore neighbors numHapBlocks s scaleFactor sub targetd tol;
        end
        
        figure(36); clf;
        maximize(figure(36)); set(figure(36), 'Position', [0,0,0.38,0.45]);
        imagesc(double(X)); colormap bone;
        set(gca,'XTick',[1:1:15])

        saveas(figure(36),['..\Results\',num2str(j),'_R','.pdf']);

        clear X;
 
        performMeanShift(j, kernelsUsed)

%        clc; close all; drawnow;
    end
end
