function out = queryDB(query)

    DBName = '..\Data\Mouse.mdb';
    
    s = ['PROVIDER=MSDASQL;DRIVER={Microsoft Access Driver (*.mdb)};'];
    s = [s 'DBQ=' DBName ';'];

    % Timeout if connection to DB can't be made in 60s
    try
        cn=COM.OWC11_DataSourceControl_11;
    catch
        cn=COM.OWC10_DataSourceControl_10;
    end
    
    cn.ConnectionString=s;
    cn.Connection.CommandTimeout=60;
    cn.RecordsetType=1;

    r = cn.connection.invoke('execute', query);
    
    if r.state && r.recordcount>0
        x = invoke(r,'getrows');
        x = x';
    else
        x = [];
    end
    
    invoke(r,'release');
    out = x;
end