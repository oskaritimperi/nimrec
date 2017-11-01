import unittest
import streams
import sequtils

import nimrec/[parser, record, recordset, utils]

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
        expect(ParseError):
            discard toSeq(records(ss))

    test "parse error if invalid label":
        let ss = newStringStream("Name: John Doe\nFoo-bar: 111")
        expect(ParseError):
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
        expect(ParseError):
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

suite "recordset":
    test "basics":
        const data = """
%rec: Entry
%doc: docs for Entry
"""

        var ss = newStringStream(data)
        var records = toSeq(records(ss))
        var rset = newRecordSet(records[0])

        check(rset.kind == "Entry")
        check(rset.doc == "docs for Entry")

    test "descriptor skipped when iterating records":
        const data = """
%rec: Entry
%doc: docs for Entry

Name: John

Name: Jane

Name: Bill
"""

        var ss = newStringStream(data)
        var records = toSeq(recordsInSet(ss, "Entry"))
        check(len(records) == 3)
        check(records[0]["Name"] == "John")
        check(records[1]["Name"] == "Jane")
        check(records[2]["Name"] == "Bill")

    test "mandatory does not raise if all present":
        const data = """
%rec: Entry
%mandatory: Name Age

Name: John
Age: 0

Name: Jane
Age: 0

Name: Bill
Age: 0
"""

        var ss = newStringStream(data)
        var records = toSeq(recordsInSet(ss, "Entry"))
        check(len(records) == 3)

    test "mandatory raises if something is missing":
        const data = """
%rec: Entry
%mandatory: Name Age

Name: John
Age: 0

Name: Jane

Name: Bill
Age: 0
"""

        var ss = newStringStream(data)
        expect(IntegrityError):
            discard toSeq(recordsInSet(ss, "Entry"))

    test "prohibit does not fail if fields not present":
        const data = """
%rec: Entry
%prohibit: result

Name: John

Name: Jane

Name: Bill
"""

        var ss = newStringStream(data)
        var records = toSeq(recordsInSet(ss, "Entry"))
        check(len(records) == 3)

    test "prohibit fails if fields present":
        const data = """
%rec: Entry
%prohibit: result

Name: John

Name: Jane

Name: Bill
result: 100
"""

        var ss = newStringStream(data)
        expect(IntegrityError):
            discard toSeq(recordsInSet(ss, "Entry"))

    test "allowed allows allowed fields":
        const data = """
%rec: Entry
%allowed: Name Age Address

Name: John

Name: Jane
Age: 29

Name: Bill
Age: 56
Address: 10 Foobar Way
"""

        var ss = newStringStream(data)
        var records = toSeq(recordsInSet(ss, "Entry"))
        check(len(records) == 3)

    test "allowed does not allow undeclared fields":
        const data = """
%rec: Entry
%allowed: Name Age Address

Name: John

Name: Jane
Age: 29
Phone: 12345

Name: Bill
Age: 56
Address: 10 Foobar Way
"""

        var ss = newStringStream(data)
        expect(IntegrityError):
            discard toSeq(recordsInSet(ss, "Entry"))

    test "mandatory and prohibit for same field fails":
        const data1 = """
%rec: Entry
%mandatory: Name
%prohibit: Name
"""

        var ss = newStringStream(data1)
        var records = toSeq(records(ss))
        expect(Exception):
            discard newRecordSet(records[0])

        const data2 = """
%rec: Entry
%prohibit: Name
%mandatory: Name
"""

        ss = newStringStream(data2)
        records = toSeq(records(ss))
        expect(Exception):
            discard newRecordSet(records[0])

    test "allowed and prohibit for same field fails":
        const data1 = """
%rec: Entry
%allowed: Name
%prohibit: Name
"""

        var ss = newStringStream(data1)
        var records = toSeq(records(ss))
        expect(Exception):
            discard newRecordSet(records[0])

        const data2 = """
%rec: Entry
%prohibit: Name
%allowed: Name
"""

        ss = newStringStream(data2)
        records = toSeq(records(ss))
        expect(Exception):
            discard newRecordSet(records[0])

suite "type basics: integers":
    const prologue = """
%rec: Entry
%type: Value int

"""

    test "valid integers":
        const values = ["0", "1", "123456789", "987654321", "-123456789",
            "-987654321", "-0"]

        for value in values:
            let data = prologue & "Value: " & value & "\n"
            discard toSeq(recordsInSet(newStringStream(data), "Entry"))

    test "invalid integers":
        const values = ["0.0", "foobar", "01", "1-"]

        for value in values:
            let data = prologue & "Value: " & value & "\n"
            expect(Exception):
                discard toSeq(recordsInSet(newStringStream(data), "Entry"))

suite "type basics: reals":
    const prologue = """
%rec: Entry
%type: Value real

"""

    test "valid reals":
        const values = ["0", "1", "123456789", "987654321", "-123456789",
            "-987654321", "-0",
            "0.0", "0.12345", "1234.5678",
            "1e8", "1E8", "1e+9", "1E-9", "1e10"]

        for value in values:
            let data = prologue & "Value: " & value & "\n"
            discard toSeq(recordsInSet(newStringStream(data), "Entry"))

    test "invalid reals":
        const values = ["0.", "foobar", "01", "1-"]

        for value in values:
            let data = prologue & "Value: " & value & "\n"
            expect(Exception):
                discard toSeq(recordsInSet(newStringStream(data), "Entry"))
