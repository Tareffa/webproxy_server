# AGENTS.md

This project is written in **Hive**, a memory-managed language that compiles to Go.
Source files end in `.hive` and the standard library is reached as `hive.*`.

## Before writing any Hive

Read [`.hivedocs/README.md`](.hivedocs/README.md) first. It indexes one short
reference page per feature of the language — syntax, types, patterns, bounds,
concurrency, and every `hive.*` module — and it opens with the eight rules that
catch everybody.

**Read the page for what you are about to touch rather than guessing the
syntax.** Hive refuses a great deal that other languages accept, and every one
of those refusals is a compile error rather than something noticed later:
an index nothing proved in range, an `append` to a vector whose length was
inferred, a condition that is not a `Bool`, a `!`.

If you read only one page, read
[`.hivedocs/pitfalls.md`](.hivedocs/pitfalls.md).

## Commands

```
hive check <entrypoint.hive>   report any errors, build nothing
hive test  <entrypoint.hive>   run the tests, with coverage
hive build <entrypoint.hive>   compile to a native executable
hive run   <entrypoint.hive>   compile and run
```

The entrypoint is the file holding `proc main(): void`, and a program is that
file plus everything it imports.

**`hive check` is the one to run after an edit**: it runs every check,
stops before any Go is written, and writes nothing beside the file.
**`hive test` exits non-zero when any test fails**, and reports coverage
without being asked.

## The language server

`hive lsp` is the compiler as a language server. **If you have a
language-server tool, ask it before reading a file to find something out**: hover
a name for its type or its signature, go to its definition, list what a file
declares. It also says what is wrong with a file after each edit.
[`.hivedocs/lsp.md`](.hivedocs/lsp.md) has what it answers and how to connect it;
for Claude Code that is `claude --plugin-dir .hivedocs/plugin`.

## Keeping the pages current

`.hivedocs/` is written by `hive agents`, out of the compiler that ran it. If
the directory is missing, or `hive` has been upgraded since, run it again:

```
hive agents
```
