import nimrec
import streams

for record in records(newFileStream("persons.rec")):
    if not hasField(record, "Email"):
        continue
    echo(record["Name"])
    for label, value in record:
        if label == "Email":
            echo("  " & value)
