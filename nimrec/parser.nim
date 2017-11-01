import record

import streams
import strutils

type
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

    ParseError* = object of Exception

const
    LabelFirstChar = {'a'..'z', 'A'..'Z', '%'}

    LabelChar = {'a'..'z', 'A'..'Z', '0'..'9', '_'}

    EofMarker = '\0'

proc newRecParser*(): RecParser =
    new(result)
    result.state = ParseState.Initial

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
                raise newException(ParseError, "parse error: expected a comment, a label or an empty line")
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
                raise newException(ParseError,
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
                raise newException(ParseError,
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
                addField(parser.record, parser.field)
                parser.field = nil
                parser.state = ParseState.Initial
                continue

        break
