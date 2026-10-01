# Mini C Compiler

A compiler front-end for a subset of the C language, built with **Flex**, **Bison**, and **C++**.
It takes a C source file through lexical analysis, parsing, scoped symbol table management,
semantic analysis, and finally generates **three-address code** by traversing an Abstract Syntax Tree.

The project was built incrementally in four stages, and each stage lives in its own folder so you can
follow how the compiler grows from a tokenizer into a working intermediate code generator.

---

## Pipeline

```
 Source (.c)
     │
     ▼
 Lexical Analysis  ──►  Syntax Analysis  ──►  Symbol Table  ──►  Semantic Analysis  ──►  AST  ──►  Three-Address Code
   (Flex)                 (Bison)             (scoped hash tables)   (type & scope checks)
```

---

## Stages

| # | Folder | What it adds |
|---|--------|--------------|
| 1 | [`Lexer-parser`](./Lexer-parser) | Tokenizes keywords, identifiers, constants, and operators; parses the C subset grammar with zero conflicts (including dangling `if-else`); logs matched grammar rules |
| 2 | [`Symbol_table_generation`](./Symbol_table_generation) | Hash-table based scope tables chained into a symbol table stack; stores variables, arrays (with size), and functions (return type, parameter list); prints scope tables on entry and exit |
| 3 | [`Semantic_Analyzer`](./Semantic_Analyzer) | Type checking, type conversion warnings, undeclared and duplicate identifier detection, array index validation, function argument count and type checking; reports all errors without stopping |
| 4 | [`Intermediate_Code_Generation`](./Intermediate_Code_Generation) | Builds an AST during parsing and generates three-address code with temporaries and labels |

---

## Supported Language Subset

- Data types: `int`, `float`, `void`
- Global and local variables, one-dimensional arrays
- Multiple function definitions with parameters and return values
- Control flow: `if`, `if-else`, `for`, `while`, `return`
- Operators:
  - Arithmetic: `+ - * / %`
  - Increment / decrement: `++ --`
  - Relational: `< > <= >= == !=`
  - Logical: `&& || !`
  - Assignment: `=`
- `printf` for output

Not supported: preprocessor directives, `switch`/`case`, `break`, and chained relational or logical
operators such as `a < b < c`.

---

## Semantic Checks (Stage 3 onward)

- Type mismatch in assignment (including float assigned to int)
- Non-integer array index
- Non-integer operands of `%`
- Division or modulus by zero
- Use of undeclared variables or functions
- Multiple declarations in the same scope
- Array used without an index, or index used on a non-array
- Function called with the wrong number or types of arguments
- Calling a non-function identifier
- Void function used inside an expression

---

## AST Design (Stage 4)

```
ASTNode
├── ExprNode
│   ├── VarNode          variable references (including array access)
│   ├── ConstNode        integer and float constants
│   ├── BinaryOpNode     + - * / % relational and logical operators
│   ├── UnaryOpNode      unary - and !
│   ├── AssignNode       assignments
│   └── FuncCallNode     function calls
├── StmtNode
│   ├── ExprStmtNode     expression statements
│   ├── BlockNode        compound statements
│   ├── IfNode           if / if-else
│   ├── WhileNode        while loops
│   ├── ForNode          for loops
│   ├── ReturnNode       return statements
│   └── DeclNode         variable declarations
└── ProgramNode          root of the tree
```

Each node implements a `generate_code` method that emits three-address code using
temporaries (`t0, t1, ...`) and labels (`L0, L1, ...`).

---

## Example

**Input**

```c
int main() {
    int a, b;
    a = 5;
    if (a > 3)
        b = a * 2;
    return 0;
}
```

**Generated three-address code**

```
a = 5
t0 = a > 3
if t0 goto L0
goto L1
L0:
t1 = a * 2
b = t1
L1:
return 0
```

More sample inputs and outputs are in each stage's folder.

---

## Building and Running

### Requirements

- `flex`
- `bison` (or `yacc`)
- `g++`

On Windows, use WSL, MSYS2, or Git Bash with these tools installed.

### Run

Each stage has its own build script. From inside a stage folder:

```bash
chmod +x script.sh
./script.sh
```

The script generates the lexer and parser, compiles them, and runs the compiler on `input.c`.

### Output files

| File | Contents |
|------|----------|
| `log.txt` | Tokens, matched grammar rules, symbol table states, line and error count |
| `error.txt` | Semantic errors and warnings with line numbers (Stage 3 onward) |
| `code.txt` | Generated three-address code (Stage 4) |

---

## Project Structure

```
Mini-C-Compiler/
├── Lexer-parser/
├── Symbol_table_generation/
├── Semantic_Analyzer/
├── Intermediate_Code_Generation/
└── README.md
```

---

## Context

Built as part of **CSE420: Compiler Design** at BRAC University.
