import nimrec/[utils, record]

for record in records("persons.rec"):
    if "Email" notin record:
        continue
    echo(record["Name"])
    for email in values(record, "Email"):
        echo("  " & email)
