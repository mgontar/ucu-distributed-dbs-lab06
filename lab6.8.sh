# Task 8: Configure a Delayed Replica Set Member
printf "Task 8: Configure a Delayed Replica Set Member\n"

sudo docker exec -it rsn1 mongo --quiet --eval "db.coll.insert({name : 'replica delay 1 - before delay'},{ writeConcern: { w: 1, j: false } });"
sudo docker exec -it rsn1 mongo --quiet --eval "cfg = rs.conf();cfg.members[2].priority = 0;cfg.members[2].hidden = true;cfg.members[2].slaveDelay = 3600;rs.reconfig(cfg);"
sleep 20s
sudo docker exec -it rsn1 mongo --quiet --eval "db.coll.insert({name : 'replica delay 2 - after delay'},{ writeConcern: { w: 1, j: false } });"
sleep 20s
printf "read rsn2 \n"
sudo docker exec -it rsn2 mongo --quiet --eval "db.setSlaveOk(); db.coll.find({name:/replica delay/});"
printf "read rsn3 \n"
sudo docker exec -it rsn3 mongo --quiet --eval "db.setSlaveOk(); db.coll.find({name:/replica delay/});"
