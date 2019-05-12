### Import
import datetime
from   pymongo       import MongoClient, ASCENDING # use mongodb scheme
from   bson.objectid import ObjectId               # handle bson format
import bson
import random

### Set database
url = 'mongodb://127.0.0.1:28001' 
client = MongoClient( url )
testdb = client['testdb']

### Set logfile
logfile = open( "size.txt", 'a' )

dataSize=testdb.command("dbstats")["dataSize"]
storageSize=testdb.command("dbstats")["storageSize"]
print(datetime.datetime.now().strftime('%Y.%m.%d_%H:%M:%S:       storage size ... {} MB'.format( storageSize/10000000. )))
indexSize=testdb.command("dbstats")["indexSize"]
fsUsedSize=testdb.command("dbstats")["fsUsedSize"]
fsTotalSize=testdb.command("dbstats")["fsTotalSize"]

logfile.write("{} ".format(dataSize))
logfile.write("{} ".format(storageSize))
logfile.write("{} ".format(indexSize))
logfile.write("{} ".format(fsUsedSize))
logfile.write("{} ".format(fsTotalSize))

collection="config"
documents=testdb[collection].find().count()
size=testdb.command("collstats", collection)["size"]
logfile.write("{} ".format(documents))
logfile.write("{} ".format(size))

collection="fs.files"
documents=testdb[collection].find().count()
size=testdb.command("collstats", collection)["size"]
with open("files_size.txt", 'w') as f: f.write(str(size))
logfile.write("{} ".format(documents))
logfile.write("{} ".format(size))

collection="fs.chunks"
documents=testdb[collection].find().count()
size=testdb.command("collstats", collection)["size"]
logfile.write("{} ".format(documents))
logfile.write("{}\n".format(size))

id_entries = testdb.config.find()
cnt=0
count=random.randint(0,id_entries.count())
for id_entry in id_entries:
    if cnt==count: 
        with open("id.txt", 'w') as f: f.write(str(id_entry['_id']))
    cnt+=1
