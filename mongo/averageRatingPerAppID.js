var result = db.app_data.aggregate(
  {$project: {app_id:1, "reviews.rating":1}}, 
  {$match: {reviews:{$exists:1}}}, 
  {$unwind: "$reviews"}, 
  {$group: {_id: "$app_id", rating: {$avg: "$reviews.rating"}}},
  {$sort: {_id:1}}
);

printjson(result);
