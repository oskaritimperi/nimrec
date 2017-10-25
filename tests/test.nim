import unittest
import streams
import sequtils

import nimrec

suite "parsing":
    test "basics":
        const data = """
Name: John Doe
Age: 34

Name: Jane Doe
Age: 32
"""

        var ss = newStringStream(data)
        var records = toSeq(records(ss))
        check(len(records) == 2)
        check(len(records[0]) == 2)
        check(len(records[1]) == 2)
        check(records[0]["Name"] == "John Doe")
        check(records[0]["Age"] == "34")
        check(records[1]["Name"] == "Jane Doe")
        check(records[1]["Age"] == "32")

    test "comments":
        const data = """
# This is a comment
Name: John Doe
Age: 34

# A comment between records
# With multiple lines!

Name: Jane Doe
# A comment between fields
Age: 32
"""

        let ss = newStringStream(data)
        let records = toSeq(records(ss))
        check(len(records) == 2)
        check(records[0]["Name"] == "John Doe")
        check(records[0]["Age"] == "34")
        check(records[1]["Name"] == "Jane Doe")
        check(records[1]["Age"] == "32")

    test "only initial whitespace skipped from values":
        const data = """
Name:  John Doe
Age:   34

Name:	Jane Doe
Age:		32
"""

        let ss = newStringStream(data)
        let records = toSeq(records(ss))
        check(len(records) == 2)
        check(records[0]["Name"] == " John Doe")
        check(records[0]["Age"] == "  34")
        check(records[1]["Name"] == "Jane Doe")
        check(records[1]["Age"] == "\t32")

    test "trailing whitespace included in values":
        const data =
            "Name: John Doe   \l" &
            "Age: 34\t\l"

        let ss = newStringStream(data)
        let records = toSeq(records(ss))
        check(len(records) == 1)
        check(records[0]["Name"] == "John Doe   ")
        check(records[0]["Age"] == "34\t")

    test "records with single field":
        const data = """
Name: John Doe

Name: Jane Doe

Name: Foobar!
"""

        let ss = newStringStream(data)
        let records = toSeq(records(ss))
        check(len(records) == 3)
        check(len(records[0]) == 1)
        check(records[0]["Name"] == "John Doe")
        check(len(records[1]) == 1)
        check(records[1]["Name"] == "Jane Doe")
        check(len(records[2]) == 1)
        check(records[2]["Name"] == "Foobar!")

    test "parse error if colon missing":
        let ss = newStringStream("Name\nAge: 34\n")
        expect(RecParseError):
            discard toSeq(records(ss))

    test "parse error if invalid label":
        let ss = newStringStream("Name: John Doe\nFoo-bar: 111")
        expect(RecParseError):
            discard toSeq(records(ss))

    test "label can start with %":
        let ss = newStringStream("%rec: Entry\n")
        let records = toSeq(records(ss))
        check(len(records) == 1)
        check(len(records[0]) == 1)
        let fields = toSeq(items(records[0]))
        check(fields[0].label == "%rec")
        check(fields[0].value == "Entry")

    test "field must be terminated by newline":
        let ss = newStringStream("%rec: Entry\n%type: Id int")
        expect(RecParseError):
            discard toSeq(records(ss))

    test "multiple fields with same label":
        const data = """
Name: John Doe
Age: 34
Email: john@doe.me
Email: john.doe@foobar.com

Name: Jane Doe
Age: 32
Email: jane@doe.me
"""

        var ss = newStringStream(data)
        var emails: seq[string] = @[]
        for record in records(ss):
            for label, value in record:
                if label == "Email":
                    add(emails, value)
        check(len(emails) == 3)
        check(emails[0] == "john@doe.me")
        check(emails[1] == "john.doe@foobar.com")
        check(emails[2] == "jane@doe.me")


suite "misc":
    test "record items iterator":
        const data = """
Name: John Doe
Age: 34

Name: Jane Doe
Age: 32
"""

        var ss = newStringStream(data)
        var fields: seq[Field] = @[]
        for record in records(ss):
            for field in record:
                add(fields, field)
        check(len(fields) == 4)
        check(fields[0].label == "Name")
        check(fields[0].value == "John Doe")
        check(fields[1].label == "Age")
        check(fields[1].value == "34")
        check(fields[2].label == "Name")
        check(fields[2].value == "Jane Doe")
        check(fields[3].label == "Age")
        check(fields[3].value == "32")

    test "record pairs iterator":
        const data = """
Name: John Doe
Age: 34

Name: Jane Doe
Age: 32
"""

        var ss = newStringStream(data)
        var results: seq[string] = @[]
        for record in records(ss):
            for label, value in record:
                add(results, label)
                add(results, value)
        check(len(results) == 8)
        check(results[0] == "Name")
        check(results[1] == "John Doe")
        check(results[2] == "Age")
        check(results[3] == "34")
        check(results[4] == "Name")
        check(results[5] == "Jane Doe")
        check(results[6] == "Age")
        check(results[7] == "32")

    test "hasField":
        const data = """
Name: John Doe
Age: 34

Name: Jane Doe
Age: 32
Email: jane@doe.me
"""

        var ss = newStringStream(data)
        var records = toSeq(records(ss))
        check(len(records) == 2)
        check(not hasField(records[0], "Email"))
        check(hasField(records[1], "Email"))

    test "contains":
        const data = """
Name: John Doe
Age: 34

Name: Jane Doe
Age: 32
Email: jane@doe.me
"""

        var ss = newStringStream(data)
        var records = toSeq(records(ss))
        check(len(records) == 2)
        check("Email" notin records[0])
        check("Email" in records[1])
