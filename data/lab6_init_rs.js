db = (new Mongo('localhost:27017')).getDB('test');
config = {
  	"_id" : "rsn-set",
  	"members" : [
  		{
  			"_id" : 0,
  			"host" : "rsn1:27017"
  		},
  		{
  			"_id" : 1,
  			"host" : "rsn2:27017"
  		},
  		{
  			"_id" : 2,
  			"host" : "rsn3:27017"
  		}
  	]
  };
rs.initiate(config);
