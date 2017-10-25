import streams
import strutils
import tables

type
    Field* = ref object
        label*: string
        value*: string

    Record* = ref object
        fields: OrderedTableRef[string, seq[string]]

    ParseState {.pure.} = enum
        Initial
        Comment
        Label
        Value
        ValueSkipSpace
        FieldReady

    RecParser* = ref object
        state: ParseState
        field: Field
        record: Record

    RecParseError* = object of Exception

const
    LabelFirstChar = {'a'..'z', 'A'..'Z', '%'}

    LabelChar = {'a'..'z', 'A'..'Z', '0'..'9', '_'}

    EofMarker = '\0'

proc newRecParser*(): RecParser =
    new(result)
    result.state = ParseState.Initial

proc newField(): Field =
    new(result)
    result.label = ""
    result.value = ""

proc newField(label, value: string): Field =
    new(result)
    result.label = label
    result.value = value

proc newRecord(): Record =
    new(result)
    result.fields = newOrderedTable[string, seq[string]]()

proc feed*(parser: RecParser, ch: char, record: var Record): bool =
    while true:
        case parser.state
        of ParseState.Initial:
            case ch
            of '#':
                parser.state = ParseState.Comment
            of '\l', EofMarker:
                if parser.record != nil:
                    result = true
                    record = parser.record
                    parser.record = nil
            of LabelFirstChar:
                parser.state = ParseState.Label
                parser.field = newField()
                parser.field.label &= ch
            else:
                raise newException(RecParseError, "parse error: expected a comment, a label or an empty line")
        of ParseState.Comment:
            case ch
            of '\l':
                parser.state = ParseState.Initial
            else: discard
        of ParseState.Label:
            case ch
            of ':':
                parser.state = ParseState.ValueSkipSpace
            of LabelChar:
                parser.field.label &= ch
            else:
                raise newException(RecParseError,
                    "parse error: invalid label char: " & ch)
        of ParseState.Value:
            case ch
            of '\l':
                let valueLen = len(parser.field.value)
                if valueLen > 0 and parser.field.value[valueLen-1] == '\\':
                    setLen(parser.field.value, valueLen - 1)
                else:
                    parser.state = ParseState.FieldReady
            of EofMarker:
                raise newException(RecParseError,
                    "parse error: value must be terminated by a newline")
            else:
                parser.field.value &= ch
        of ParseState.ValueSkipSpace:
            case ch
            of (WhiteSpace - NewLines):
                discard
            else:
                parser.field.value &= ch
            parser.state = ParseState.Value
        of ParseState.FieldReady:
            case ch
            of '+':
                parser.state = ParseState.ValueSkipSpace
                parser.field.value &= '\l'
            else:
                if parser.record == nil:
                    parser.record = newRecord()
                if hasKey(parser.record.fields, parser.field.label):
                    add(parser.record.fields[parser.field.label], parser.field.value)
                else:
                    add(parser.record.fields, parser.field.label,
                        @[parser.field.value])
                parser.field = nil
                parser.state = ParseState.Initial
                continue

        break

proc `[]`*(record: Record, label: string): string =
    result = record.fields[label][0]

proc len*(record: Record): int =
    result = len(record.fields)

iterator records*(stream: Stream): Record =
    let parser = newRecParser()
    var record: Record

    while true:
        var ch = readChar(stream)

        if feed(parser, ch, record):
            yield record

        if ch == EofMarker:
            break

iterator pairs*(record: Record): (string, string) =
    for label, values in record.fields:
        for value in values:
            yield (label, value)

iterator items*(record: Record): Field =
    for label, value in record:
        yield newField(label, value)

proc hasField*(record: Record, label: string): bool =
    for field in record:
        if field.label == label:
            return true

proc contains*(record: Record, label: string): bool =
    result = hasField(record, label)
