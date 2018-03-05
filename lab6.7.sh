# Task 7: Read Concern
printf "Task 7: Read Concern\n"
sudo docker exec -it rsn1 mongo --quiet --eval "db.coll.insert({name : 'read concern at rsn1 - local'},{ writeConcern: { w: 1, j: false } });"
sudo docker exec -it rsn2 mongo --quiet --eval "db.setSlaveOk(); db.coll.find({name:/read concern/}).readConcern('local');"
sudo docker exec -it rsn1 mongo --quiet --eval "db.coll.insert({name : 'read concern at rsn1 - majority'},{ writeConcern: { w: 1, j: false } });"
sudo docker exec -it rsn2 mongo --quiet --eval "db.setSlaveOk(); db.coll.find({name:/read concern/}).readConcern('majority');"
sudo docker exec -it rsn1 mongo --quiet --eval "db.coll.insert({name : 'read concern at rsn1 - linearizable'},{ writeConcern: { w: 1, j: false } });"
sudo docker exec -it rsn1 mongo --quiet --eval "db.coll.find({name:/read concern/}).readConcern('linearizable');"
