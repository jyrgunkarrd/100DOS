# 100 Days of Sin - Palette Builder

Run from the project directory with LÖVE installed.

```bat
love . --palette "C:\Users\Kevin R Brown\Documents\palette-example.txt"
```

The tool can also run independently. Its folder can be copied outside the game.

```bat
love tools/palette "C:\Users\Kevin R Brown\Documents\palette-example.txt"
love tools/palette
```

Drop a text file into the window to open it. Input accepts one six-digit RGB hex
color per line, with an optional `#`. Letter case, blank lines, surrounding spaces,
Windows line endings, and a UTF-8 BOM are supported. Whole lines beginning with
`//` are comments. All other nonempty lines must be valid colors. Errors name the
source line. Duplicate colors collapse to their first occurrence, preserving order.
Failed loads and reloads retain the last successful preview.

The initial layout uses ten columns and 48-pixel swatches. Use the minus/plus
buttons to change columns or swatch size. Scroll the grid when needed. Click a
swatch and use Copy hex or Ctrl+C to copy its hex value. R reloads the source file.
E exports the PNG. Tab selects the output path for editing, Ctrl+A selects all,
Ctrl+V pastes, and Enter finishes editing. Escape leaves the output field or closes
the tool. Output editing appends text and supports backspace.

Export defaults to a PNG beside the input file. Change its path in the output
field. The destination folder must exist. Export replaces an existing destination
PNG. Paths resolve from the command working directory. Source text cannot be used
as the output path. Failure details are also printed in the console.

For a single export that exits automatically, use either launch route.

```bat
love . --palette "colors.txt" --export "colors.png" --columns 10 --swatch 48
love tools/palette "colors.txt" --export "colors.png" --columns 8 --swatch 32
```

Batch export runs with a hidden window and returns exit code 0 on success or 1 on
failure. Use `lovec` in place of `love` on Windows to capture console diagnostics.
Use `--help` to print usage. Columns and swatch size each accept integers from 1
through 256. Export images are limited to 16,777,216 pixels.

Every export pixel is opaque and exactly matches an imported RGB color. Export
contains every unique imported color, with no labels, borders, or gaps. Unused
cells in the final row repeat the final color. The preview includes those padding
cells. Pixels are built as RGBA8 with fully opaque alpha and validated directly
before PNG encoding. The encoder may optimize the PNG into indexed color.

Tool modules contain text parsing, layout, file paths, export, defaults, and UI.
The game entry points only select this utility when `--palette` is supplied.
