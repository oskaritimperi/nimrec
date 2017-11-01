import nimrec/[utils, record]

for record in records("persons.rec"):
    if not hasField(record, "Email"):
        continue
    echo(record["Name"])
    for label, value in record:
        if label == "Email":
            echo("  " & value)
