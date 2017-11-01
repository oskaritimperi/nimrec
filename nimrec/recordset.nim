import parser
import record
import utils

import sequtils
import sets
import streams
import strutils
import tables
import times

type
    RecordSet* = ref object
        kind*: string
        doc*: string
        mandatory*: HashSet[string]
        allowed*: HashSet[string]
        prohibited*: HashSet[string]

    IntegrityError* = object of Exception

proc newRecordSet*(record: Record): RecordSet =
    new(result)

    init(result.mandatory)
    init(result.prohibited)
    init(result.allowed)

    result.kind = record["%rec"]

    if "%doc" in record:
        result.doc = record["%doc"]

    for value in values(record, "%mandatory"):
        for field in split(value):
            incl(result.mandatory, field)
            incl(result.allowed, field)
            if field in result.prohibited:
                raise newException(Exception, "a field cannot be mandatory and prohibited at the same time")

    for value in values(record, "%prohibit"):
        for field in split(value):
            if field in result.mandatory:
                raise newException(Exception, "a field cannot be mandatory and prohibited at the same time")
            if field in result.allowed:
                raise newException(Exception, "a field cannot be allowed and prohibited at the same time")
            incl(result.prohibited, field)

    for value in values(record, "%allowed"):
        for field in split(value):
            if field in result.prohibited:
                raise newException(Exception, "a field cannot be allowed and prohibited at the same time")
            incl(result.allowed, field)

proc validate*(record: Record, recordSet: RecordSet) =
    let labels = toSet(toSeq(labels(record)))

    for label in labels(record):
        if len(recordSet.allowed) > 0:
            if label notin recordSet.allowed:
                raise newException(IntegrityError, format("not allowed: $1", label))

        if label in recordSet.prohibited:
            raise newException(IntegrityError, format("prohibited: $1", label))

    for mandatoryLabel in recordSet.mandatory:
        if mandatoryLabel notin labels:
            raise newException(IntegrityError, format("mandatory: $1",
                mandatoryLabel))

iterator recordsInSet*(stream: Stream, kind: string): Record =
    var
        currentSet: RecordSet = nil

    for record in records(stream):
        if currentSet == nil:
            if "%rec" in record and record["%rec"] == kind:
                currentSet = newRecordSet(record)
            continue
        else:
            if "%rec" in record and record["%rec"] == kind:
                currentSet = newRecordSet(record)
                continue
            elif "%rec" in record:
                currentSet = nil
                continue

        validate(record, currentSet)

        yield record
