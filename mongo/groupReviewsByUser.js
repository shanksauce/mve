var result = db.app_data.aggregate(
  {$project: {app_id:1, "reviews.author_name":1, "reviews.author_id":1}}, 
  {$match: {reviews:{$exists:1}}}, 
  {$unwind: "$reviews"},
  {$group: {
  	_id: {author_id: "$reviews.author_id", author_name: "$reviews.author_name"},
  	app_ids: {$push: "$app_id"},
  	total: {$sum:1}
  }},
  {$sort: {total:-1}}
);

printjson(result);
