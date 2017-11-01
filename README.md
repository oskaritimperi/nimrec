# Rec file parser for Nim

Using this library you can parse rec files made by the
[recutils](https://www.gnu.org/software/recutils/) software.

# Examples

If you have the following recfile:

```
Name: John Doe
Age: 34

Name: Jane Doe
Age: 32
```

You can read the names of the persons like this:

```nim
import nimrec/[utils, record]

for record in records("persons.rec"):
    echo(record["Name"])
```

More examples can be found in the `examples` directory.
