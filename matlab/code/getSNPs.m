function SNPs = getSNPs
    clc; close all; clear all;

    
    for chromosome = 2:22
        SNPs = {};

        minHapBlock = queryDB(strcat('select min(id) from HaplotypeBlockSummary WHERE CHROMOSOME LIKE ', chromosomes(chromosome)));
        maxHapBlock = queryDB(strcat('select max(id) from HaplotypeBlockSummary WHERE CHROMOSOME LIKE ', chromosomes(chromosome)));
        
        minHapBlock = minHapBlock{1};
        maxHapBlock = maxHapBlock{1};
        
        j=1;
        for hapBlockID = minHapBlock:maxHapBlock
            hapBlockID
            [minBP, maxBP] = getRange(chromosome, hapBlockID);
            SNPs{j}.SNPs = queryDB(strcat('SELECT ASC([DBA/2J]), ASC([A/J]), ASC([BALB/cByJ]), ASC([C3H/HeJ]), ASC([AKR/J]), ASC([FVB/NJ]), ASC([129S1/SvImJ]), ASC([NOD/LtJ]), ASC([WSB/EiJ]), ASC([PWD/PhJ]), ASC([BTBR T+ tf/J]), ASC([CAST/EiJ]), ASC([MOLF/EiJ]), ASC([NZW/LacJ]), ASC([KK/HlJ]) FROM Genotypes WHERE POSITION BETWEEN ', sprintf(' %i AND %i ', minBP, maxBP), 'AND CHROMOSOME LIKE ', chromosomes(chromosome)));
            SNPs{j}.ID   = hapBlockID;
            j = j+1;
        end
        
        if chromosome > 9
            fileName = sprintf('SNPsChr%2.0f.mat',chromosome);
        else
            fileName = sprintf('SNPsChr0%1.0f.mat',chromosome);
        end
        save(fileName, 'SNPs');
    end
    
    
end


function [minBP, maxBP] = getRange(chromosome, hapBlockID)
    q = queryDB(strcat('SELECT TOP 5 BLOCK_START_BP, BLOCK_END_BP FROM HaplotypeBlockSummary WHERE CHROMOSOME = ', chromosomes(chromosome), ' AND ID = ', num2str(hapBlockID)));
    minBP = q{1};
    maxBP = q{2};
end