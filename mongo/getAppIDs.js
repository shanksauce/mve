db.app_data.find().forEach(function(x) {
  var id = /id([0-9]+)/.exec(x.application_url);
  x.app_id = new NumberLong(id[1]);
  db.app_data.save(x);
});
