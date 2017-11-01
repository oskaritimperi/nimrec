import nimrec/[utils, record]

for record in records("persons.rec"):
    echo(record["Name"])
