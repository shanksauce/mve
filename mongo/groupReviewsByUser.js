var map = function() {
    var id = this._id;
    if(this.value.reviews) {
        this.value.reviews.forEach(function(r) {
            var k = id + ',' + r.author;
            emit(k, r.rating);
        });
    }
};

var reduce = function(k,v) {
    return {'r': v};
};

var result = db.ratings_by_user_id.mapReduce(map, reduce, {
    out: {replace: "cleaned_up_ratings"},
    query: {"value.reviews":{$exists:1}},
    sort: {_id: 1},
    limit: 100
});

printjson(result);



