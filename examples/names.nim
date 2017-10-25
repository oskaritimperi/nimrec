import nimrec
import streams

for record in records(newFileStream("persons.rec")):
    echo(record["Name"])
