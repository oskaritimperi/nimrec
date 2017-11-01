import times
import strutils

type
    Field* = ref object
        value*: string
        label*: string

    Record* = ref object
        fields: seq[Field]

proc newField*(): Field =
    new(result)
    result.label = ""
    result.value = ""

proc newField*(label, value: string): Field =
    new(result)
    result.label = label
    result.value = value

proc newRecord*(): Record =
    new(result)
    result.fields = @[]

proc getField*(record: Record, label: string): Field =
    for field in record.fields:
        if field.label == label:
            return field
    raise newException(KeyError, format("no such field: $1", label))

proc `[]`*(record: Record, label: string): string =
    result = getField(record, label).value

proc len*(record: Record): int =
    result = len(record.fields)

iterator pairs*(record: Record): (string, string) =
    for field in record.fields:
        yield (field.label, field.value)

iterator items*(record: Record): Field =
    for field in record.fields:
        yield field

iterator values*(record: Record, label: string): string =
    for k, v in record:
        if label == k:
            yield v

iterator labels*(record: Record): string =
    for field in record:
        yield field.label

proc hasField*(record: Record, label: string): bool =
    for field in record:
        if field.label == label:
            return true

proc contains*(record: Record, label: string): bool =
    result = hasField(record, label)

proc addField*(record: Record, field: Field) =
    add(record.fields, field)
