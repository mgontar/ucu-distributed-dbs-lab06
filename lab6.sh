#!/bin/bash

reset

printf "Clear previouse setup\n"

sudo docker stop rsn1 rsn2 rsn3
sudo docker rm rsn1 rsn2 rsn3
sudo docker stop cs1 shn1 shn2 rtn1
sudo docker rm cs1 shn1 shn2 rtn1
sudo docker network rm rsn-net


# Task 1: init
printf "Task 1: init 3-node replica set\n"

sudo docker pull mongo

sudo docker network create rsn-net

sudo docker run -d -v /home/mgontar/dev/lab6/data:/root/data \
-p 30001:27017 --name rsn1 --net rsn-net \
mongo mongod --replSet rsn-set

sudo docker run -d -p 30002:27017 --name rsn2 --net rsn-net mongo mongod --replSet rsn-set

sudo docker run -d -p 30003:27017 --name rsn3 --net rsn-net mongo mongod --replSet rsn-set

sleep 10s

sudo docker exec -it rsn1 mongo --quiet --eval "load('root/data/lab6_init_rs.js');"

sleep 20s

#sudo docker exec -it rsn1 mongo --eval 'db.isMaster();'


# Task 2: Write Concern Levels
printf "Task 2: Write Concern Levels\n"

sudo docker exec -it rsn1 mongo --quiet --eval "
db.coll.insert({name : 'write - no acknowledged, no journaling'},
{ writeConcern: { w: 0, j: false } });
db.coll.find({name : 'write - no acknowledged, no journaling'});"

sudo docker exec -it rsn1 mongo --quiet --eval "
db.coll.insert({name : 'write - acknowledged, no journaling'},
{ writeConcern: { w: 1, j: false } });
db.coll.find({name : 'write - acknowledged, no journaling'});"

sudo docker exec -it rsn1 mongo --quiet --eval "
db.coll.insert({name : 'write - acknowledged, journaling'},
{ writeConcern: { w: 1, j: true } });
db.coll.find({name : 'write - acknowledged, journaling'});"

sudo docker exec -it rsn1 mongo --quiet --eval "
db.coll.insert({name : 'write - whole replica acknowledged, journaling'},
{ writeConcern: { w: 3, j: true } });
db.coll.find({name : 'write - whole replica acknowledged, journaling'});"

# Task 3: Read Preferences
printf "Task 3: Read Preferences\n"

sudo docker exec -it rsn1 mongo --quiet --eval "
db.coll.insert({name : 'read pref - primary'},
{ writeConcern: { w: 0, j: false } });
db.coll.find({name : 'read pref - primary'}).readPref('primary');"

sudo docker exec -it rsn1 mongo --eval "
db.coll.insert({name : 'read pref - secondary'},
{ writeConcern: { w: 0, j: false } });
db.coll.find({name : 'read pref - secondary'}).readPref('secondary');"

# Task 4: Off node and write w:3
printf "Task 4: Off node and write w:3\n"

sudo docker network disconnect rsn-net rsn3

gnome-terminal --working-directory='/home/mgontar/dev/lab6' \
-- bash -c "sudo docker exec -it rsn1 mongo --quiet --eval \"
db.coll.insert({name : 'write - whole replica acknowledged, no timeout'},
{ writeConcern: { w: 3 } });
db.coll.find({name : 'write - whole replica acknowledged, no timeout'});\"; exec bash;"

read -p 'Press Enter to continue...' var

sudo docker network connect rsn-net rsn3

sleep 10s
# Task 5: Replica Set Elections
printf "Task 5: Replica Set Elections\n"

printf "State at begin\n"
sudo docker exec -it rsn1 mongo --quiet --eval 'rs.status().members.forEach(function(z){printjson(z.name);printjson(z.stateStr);});'
sudo docker network disconnect rsn-net rsn1
sleep 20s
printf "State after rsn1 disconnected\n"
sudo docker exec -it rsn2 mongo --quiet --eval 'rs.status().members.forEach(function(z){printjson(z.name);printjson(z.stateStr);});'
sudo docker network connect rsn-net rsn1
sleep 20s
printf "State after rsn1 reconnected\n"
sudo docker exec -it rsn1 mongo --quiet --eval 'rs.status().members.forEach(function(z){printjson(z.name);printjson(z.stateStr);});'

printf "Make rsn1 primary again\n"
sudo docker exec -it rsn1 mongo --quiet --eval 'cfg = rs.conf();cfg.members[0].priority = 1;cfg.members[1].priority = 0.5;cfg.members[2].priority = 0.5;rs.reconfig(cfg, { force: true });'
sleep 20s
sudo docker exec -it rsn1 mongo --quiet --eval 'rs.status().members.forEach(function(z){printjson(z.name);printjson(z.stateStr);});'
sudo docker exec -it rsn1 mongo --quiet --eval 'cfg = rs.conf();cfg.members[0].priority = 1;cfg.members[1].priority = 1;cfg.members[2].priority = 1;rs.reconfig(cfg, { force: true });'

# Task 6: Trying to provoke inconsistency
printf "Task 6: Trying to provoke inconsistency\n"
printf "Disconnect rsn2\n"
sudo docker network disconnect rsn-net rsn2
printf "Insert data at rsn1\n"
sudo docker exec -it rsn1 mongo --quiet --eval "db.coll.insert({name : 'some data at rsn1'},{ writeConcern: { w: 0, j: false } });"
printf "Disconnect rsn1\n"
sudo docker network disconnect rsn-net rsn1
printf "Connect rsn2\n"
sudo docker network connect rsn-net rsn2
sleep 20s
printf "Read data from rsn2\n"
sudo docker exec -it rsn2 mongo --quiet --eval "db.setSlaveOk(); db.coll.find( { name: 'some data at rsn1' });"
sudo docker network connect rsn-net rsn1
sleep 20s
printf "Make rsn1 primary again\n"
sudo docker exec -it rsn1 mongo --quiet --eval 'cfg = rs.conf();cfg.members[0].priority = 1;cfg.members[1].priority = 0.5;cfg.members[2].priority = 0.5;rs.reconfig(cfg, { force: true });'
sleep 20s
sudo docker exec -it rsn1 mongo --quiet --eval 'rs.status().members.forEach(function(z){printjson(z.name);printjson(z.stateStr);});'
sudo docker exec -it rsn1 mongo --quiet --eval 'cfg = rs.conf();cfg.members[0].priority = 1;cfg.members[1].priority = 1;cfg.members[2].priority = 1;rs.reconfig(cfg, { force: true });'

# Task 7: Read Concern
printf "Task 7: Read Concern\n"
sudo docker exec -it rsn1 mongo --quiet --eval "db.coll.insert({name : 'read concern at rsn1 - local'},{ writeConcern: { w: 1, j: false } });"
sudo docker exec -it rsn2 mongo --quiet --eval "db.setSlaveOk(); db.coll.find({name:/read concern/}).readConcern('local');"
sudo docker exec -it rsn1 mongo --quiet --eval "db.coll.insert({name : 'read concern at rsn1 - majority'},{ writeConcern: { w: 1, j: false } });"
sudo docker exec -it rsn2 mongo --quiet --eval "db.setSlaveOk(); db.coll.find({name:/read concern/}).readConcern('majority');"
sudo docker exec -it rsn1 mongo --quiet --eval "db.coll.insert({name : 'read concern at rsn1 - linearizable'},{ writeConcern: { w: 1, j: false } });"
sudo docker exec -it rsn1 mongo --quiet --eval "db.coll.find({name:/read concern/}).readConcern('linearizable');"

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
