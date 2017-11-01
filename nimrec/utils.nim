import parser
import record

import streams

iterator records*(stream: Stream): Record =
    let parser = newRecParser()
    var record: Record

    while true:
        var ch = readChar(stream)

        if feed(parser, ch, record):
            yield record

        if ch == '\0':
            break

iterator records*(filename: string): Record =
    let stream = newFileStream(filename)
    for record in records(stream):
        yield record
