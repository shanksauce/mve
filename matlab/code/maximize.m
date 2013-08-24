function maximize(h)
    screen=get(0,'screensize');
    
    if screen(3)==800
        set(h,'Units','normalized','Position',[0 0.0467 1.00 0.84])
    elseif screen(3)==1024
        set(h,'Units','normalized','Position',[0.00 0.032 1.00 0.92])
    elseif screen(3)==1152
        set(h,'Units','normalized','Position',[0.00 0.032 1.00 0.89])
    elseif screen(3)==1280
        set(h,'Units','normalized','Position',[0.00 0.032 1.00 0.895])
    elseif screen(3)==1600
        set(h,'Units','normalized','Position',[0.00 0.032 1.00 0.905])
    elseif screen(3)==1920
        set(h,'Units','normalized','Position',[0.00 0.0417 1.000 0.9025])
    end 
    drawnow;
end