%{

#include <bits/stdc++.h>

#include "symbol_info.h"

#define YYSTYPE symbol_info*

int yyparse(void);
int yylex(void);
int yyerror(const char *s);

extern FILE *yyin;

ofstream outlog;

int line_num = 1;

%}

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE
%right ASSIGNOP
%left LOGICOP
%left RELOP
%left ADDOP
%left MULOP
%right NOT

%token IF ELSE FOR WHILE DO SWITCH CASE DEFAULT BREAK CONTINUE
%token INT FLOAT VOID CHAR DOUBLE RETURN PRINTLN GOTO
%token ADDOP MULOP RELOP LOGICOP ASSIGNOP NOT
%token LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA COLON SEMICOLON
%token ID CONST_INT CONST_FLOAT INCOP DECOP

%%

start : program
	{
		outlog << "At line no: " << line_num << " start : program " << endl << endl;
	}
	;

program : program unit
	{
		outlog << "At line no: " << line_num << " program : program unit " << endl << endl;
		outlog << $1->getnameofsymbol() + "\n" + $2->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol() + "\n" + $2->getnameofsymbol(), "program");
	}
	| unit
	{
		outlog << "At line no: " << line_num << " program : unit " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "program");
	}
	;

unit : variable_decl
	{
		outlog << "At line no: " << line_num << " unit : variable_decl " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "unit");
	}
	| func_definition
	{
		outlog << "At line no: " << line_num << " unit : func_definition " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "unit");
	}
	| func_declaration
	{
		outlog << "At line no: " << line_num << " unit : func_declaration " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "unit");
	}
	;

func_declaration : type_specifier ID LPAREN param_list RPAREN SEMICOLON
	{
		string text = $1->getnameofsymbol() + " " + $2->getnameofsymbol() + "(" + $4->getnameofsymbol() + ");";
		outlog << "At line no: " << line_num << " func_declaration : type_specifier ID LPAREN param_list RPAREN SEMICOLON " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "func_declaration");
	}
	| type_specifier ID LPAREN RPAREN SEMICOLON
	{
		string text = $1->getnameofsymbol() + " " + $2->getnameofsymbol() + "();";
		outlog << "At line no: " << line_num << " func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "func_declaration");
	}
	;

func_definition : type_specifier ID LPAREN param_list RPAREN compound_statement
	{
		string text = $1->getnameofsymbol() + " " + $2->getnameofsymbol() + "(" + $4->getnameofsymbol() + ")\n" + $6->getnameofsymbol();
		outlog << "At line no: " << line_num << " func_definition : type_specifier ID LPAREN param_list RPAREN compound_statement " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "func_definition");
	}
	| type_specifier ID LPAREN RPAREN compound_statement
	{
		string text = $1->getnameofsymbol() + " " + $2->getnameofsymbol() + "()\n" + $5->getnameofsymbol();
		outlog << "At line no: " << line_num << " func_definition : type_specifier ID LPAREN RPAREN compound_statement " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "func_definition");
	}
	;

type_specifier : INT
	{
		outlog << "At line no: " << line_num << " type_specifier : INT " << endl << endl;
		outlog << "int" << endl << endl;
		$$ = new symbol_info("int", "type_specifier");
	}
	| FLOAT
	{
		outlog << "At line no: " << line_num << " type_specifier : FLOAT " << endl << endl;
		outlog << "float" << endl << endl;
		$$ = new symbol_info("float", "type_specifier");
	}
	| VOID
	{
		outlog << "At line no: " << line_num << " type_specifier : VOID " << endl << endl;
		outlog << "void" << endl << endl;
		$$ = new symbol_info("void", "type_specifier");
	}
	| CHAR
	{
		outlog << "At line no: " << line_num << " type_specifier : CHAR " << endl << endl;
		outlog << "char" << endl << endl;
		$$ = new symbol_info("char", "type_specifier");
	}
	| DOUBLE
	{
		outlog << "At line no: " << line_num << " type_specifier : DOUBLE " << endl << endl;
		outlog << "double" << endl << endl;
		$$ = new symbol_info("double", "type_specifier");
	}
	;

param_list : param_list COMMA type_specifier ID
	{
		string text = $1->getnameofsymbol() + "," + $3->getnameofsymbol() + " " + $4->getnameofsymbol();
		outlog << "At line no: " << line_num << " param_list : param_list COMMA type_specifier ID " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "param_list");
	}
	| param_list COMMA type_specifier
	{
		string text = $1->getnameofsymbol() + "," + $3->getnameofsymbol();
		outlog << "At line no: " << line_num << " param_list : param_list COMMA type_specifier " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "param_list");
	}
	| type_specifier ID
	{
		string text = $1->getnameofsymbol() + " " + $2->getnameofsymbol();
		outlog << "At line no: " << line_num << " param_list : type_specifier ID " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "param_list");
	}
	| type_specifier
	{
		outlog << "At line no: " << line_num << " param_list : type_specifier " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "param_list");
	}
	;

compound_statement : LCURL statements RCURL
	{
		string text = "{\n" + $2->getnameofsymbol() + "\n}";
		outlog << "At line no: " << line_num << " compound_statement : LCURL statements RCURL " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "compound_statement");
	}
	| LCURL RCURL
	{
		outlog << "At line no: " << line_num << " compound_statement : LCURL RCURL " << endl << endl;
		outlog << "{}" << endl << endl;
		$$ = new symbol_info("{}", "compound_statement");
	}
	;

statements : statements statement
	{
		string text = $1->getnameofsymbol();
		if (!text.empty())
		{
			text += "\n";
		}
		text += $2->getnameofsymbol();
		outlog << "At line no: " << line_num << " statements : statements statement " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "statements");
	}
	| statement
	{
		outlog << "At line no: " << line_num << " statements : statement " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "statements");
	}
	;

statement : variable_decl
	{
		outlog << "At line no: " << line_num << " statement : variable_decl " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "statement");
	}
	| expression_statement
	{
		outlog << "At line no: " << line_num << " statement : expression_statement " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "statement");
	}
	| compound_statement
	{
		outlog << "At line no: " << line_num << " statement : compound_statement " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "statement");
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement
	{
		string text = "for(" + $3->getnameofsymbol() + $4->getnameofsymbol() + $5->getnameofsymbol() + ")\n" + $7->getnameofsymbol();
		outlog << "At line no: " << line_num << " statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "statement");
	}
	| WHILE LPAREN expression RPAREN statement
	{
		string text = "while(" + $3->getnameofsymbol() + ")\n" + $5->getnameofsymbol();
		outlog << "At line no: " << line_num << " statement : WHILE LPAREN expression RPAREN statement " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "statement");
	}
	| DO statement WHILE LPAREN expression RPAREN SEMICOLON
	{
		string text = "do\n" + $2->getnameofsymbol() + "\nwhile(" + $5->getnameofsymbol() + ");";
		outlog << "At line no: " << line_num << " statement : DO statement WHILE LPAREN expression RPAREN SEMICOLON " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "statement");
	}
	| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
	{
		string text = "if(" + $3->getnameofsymbol() + ")\n" + $5->getnameofsymbol();
		outlog << "At line no: " << line_num << " statement : IF LPAREN expression RPAREN statement " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "statement");
	}
	| IF LPAREN expression RPAREN statement ELSE statement
	{
		string text = "if(" + $3->getnameofsymbol() + ")\n" + $5->getnameofsymbol() + "\nelse\n" + $7->getnameofsymbol();
		outlog << "At line no: " << line_num << " statement : IF LPAREN expression RPAREN statement ELSE statement " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "statement");
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON
	{
		string text = "printf(" + $3->getnameofsymbol() + ");";
		outlog << "At line no: " << line_num << " statement : PRINTLN LPAREN ID RPAREN SEMICOLON " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "statement");
	}
	| RETURN expression SEMICOLON
	{
		string text = "return " + $2->getnameofsymbol() + ";";
		outlog << "At line no: " << line_num << " statement : RETURN expression SEMICOLON " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "statement");
	}
	| RETURN SEMICOLON
	{
		outlog << "At line no: " << line_num << " statement : RETURN SEMICOLON " << endl << endl;
		outlog << "return;" << endl << endl;
		$$ = new symbol_info("return;", "statement");
	}
	| BREAK SEMICOLON
	{
		outlog << "At line no: " << line_num << " statement : BREAK SEMICOLON " << endl << endl;
		outlog << "break;" << endl << endl;
		$$ = new symbol_info("break;", "statement");
	}
	| CONTINUE SEMICOLON
	{
		outlog << "At line no: " << line_num << " statement : CONTINUE SEMICOLON " << endl << endl;
		outlog << "continue;" << endl << endl;
		$$ = new symbol_info("continue;", "statement");
	}
	;

expression_statement : expression SEMICOLON
	{
		string text = $1->getnameofsymbol() + ";";
		outlog << "At line no: " << line_num << " expression_statement : expression SEMICOLON " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "expression_statement");
	}
	| SEMICOLON
	{
		outlog << "At line no: " << line_num << " expression_statement : SEMICOLON " << endl << endl;
		outlog << ";" << endl << endl;
		$$ = new symbol_info(";", "expression_statement");
	}
	;

variable_decl : type_specifier declaration_list SEMICOLON
	{
		string text = $1->getnameofsymbol() + " " + $2->getnameofsymbol() + ";";
		outlog << "At line no: " << line_num << " variable_decl : type_specifier declaration_list SEMICOLON " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "variable_decl");
	}
	;

declaration_list : declaration_list COMMA ID
	{
		string text = $1->getnameofsymbol() + "," + $3->getnameofsymbol();
		outlog << "At line no: " << line_num << " declaration_list : declaration_list COMMA ID " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "declaration_list");
	}
	| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
	{
		string text = $1->getnameofsymbol() + "," + $3->getnameofsymbol() + "[" + $5->getnameofsymbol() + "]";
		outlog << "At line no: " << line_num << " declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "declaration_list");
	}
	| ID
	{
		outlog << "At line no: " << line_num << " declaration_list : ID " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "declaration_list");
	}
	| ID LTHIRD CONST_INT RTHIRD
	{
		string text = $1->getnameofsymbol() + "[" + $3->getnameofsymbol() + "]";
		outlog << "At line no: " << line_num << " declaration_list : ID LTHIRD CONST_INT RTHIRD " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "declaration_list");
	}
	;

expression : variable ASSIGNOP logic_expression
	{
		string text = $1->getnameofsymbol() + "=" + $3->getnameofsymbol();
		outlog << "At line no: " << line_num << " expression : variable ASSIGNOP logic_expression " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "expression");
	}
	| logic_expression
	{
		outlog << "At line no: " << line_num << " expression : logic_expression " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "expression");
	}
	;

logic_expression : logic_expression LOGICOP rel_expression
	{
		string text = $1->getnameofsymbol() + $2->getnameofsymbol() + $3->getnameofsymbol();
		outlog << "At line no: " << line_num << " logic_expression : logic_expression LOGICOP rel_expression " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "logic_expression");
	}
	| rel_expression
	{
		outlog << "At line no: " << line_num << " logic_expression : rel_expression " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "logic_expression");
	}
	;

rel_expression : rel_expression RELOP simple_expression
	{
		string text = $1->getnameofsymbol() + $2->getnameofsymbol() + $3->getnameofsymbol();
		outlog << "At line no: " << line_num << " rel_expression : rel_expression RELOP simple_expression " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "rel_expression");
	}
	| simple_expression
	{
		outlog << "At line no: " << line_num << " rel_expression : simple_expression " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "rel_expression");
	}
	;

simple_expression : simple_expression ADDOP term
	{
		string text = $1->getnameofsymbol() + $2->getnameofsymbol() + $3->getnameofsymbol();
		outlog << "At line no: " << line_num << " simple_expression : simple_expression ADDOP term " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "simple_expression");
	}
	| term
	{
		outlog << "At line no: " << line_num << " simple_expression : term " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "simple_expression");
	}
	;

term : term MULOP unary_expression
	{
		string text = $1->getnameofsymbol() + $2->getnameofsymbol() + $3->getnameofsymbol();
		outlog << "At line no: " << line_num << " term : term MULOP unary_expression " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "term");
	}
	| unary_expression
	{
		outlog << "At line no: " << line_num << " term : unary_expression " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "term");
	}
	;

unary_expression : ADDOP unary_expression
	{
		string text = $1->getnameofsymbol() + $2->getnameofsymbol();
		outlog << "At line no: " << line_num << " unary_expression : ADDOP unary_expression " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "unary_expression");
	}
	| NOT unary_expression
	{
		string text = "!" + $2->getnameofsymbol();
		outlog << "At line no: " << line_num << " unary_expression : NOT unary_expression " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "unary_expression");
	}
	| factor_info
	{
		outlog << "At line no: " << line_num << " unary_expression : factor_info " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "unary_expression");
	}
	;

factor_info : factor
	{
		outlog << "At line no: " << line_num << " factor_info : factor " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "factor_info");
	}
	;

factor : variable
	{
		outlog << "At line no: " << line_num << " factor : variable " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "factor");
	}
	| variable INCOP
	{
		string text = $1->getnameofsymbol() + "++";
		outlog << "At line no: " << line_num << " factor : variable INCOP " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "factor");
	}
	| variable DECOP
	{
		string text = $1->getnameofsymbol() + "--";
		outlog << "At line no: " << line_num << " factor : variable DECOP " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "factor");
	}
	| ID LPAREN argument_list RPAREN
	{
		string text = $1->getnameofsymbol() + "(" + $3->getnameofsymbol() + ")";
		outlog << "At line no: " << line_num << " factor : ID LPAREN argument_list RPAREN " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "factor");
	}
	| ID LPAREN RPAREN
	{
		string text = $1->getnameofsymbol() + "()";
		outlog << "At line no: " << line_num << " factor : ID LPAREN RPAREN " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "factor");
	}
	| LPAREN expression RPAREN
	{
		string text = "(" + $2->getnameofsymbol() + ")";
		outlog << "At line no: " << line_num << " factor : LPAREN expression RPAREN " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "factor");
	}
	| CONST_INT
	{
		outlog << "At line no: " << line_num << " factor : CONST_INT " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "factor");
	}
	| CONST_FLOAT
	{
		outlog << "At line no: " << line_num << " factor : CONST_FLOAT " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "factor");
	}
	;

variable : ID
	{
		outlog << "At line no: " << line_num << " variable : ID " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "variable");
	}
	| ID LTHIRD expression RTHIRD
	{
		string text = $1->getnameofsymbol() + "[" + $3->getnameofsymbol() + "]";
		outlog << "At line no: " << line_num << " variable : ID LTHIRD expression RTHIRD " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "variable");
	}
	;

argument_list : arguments
	{
		outlog << "At line no: " << line_num << " argument_list : arguments " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "argument_list");
	}
	;

arguments : arguments COMMA logic_expression
	{
		string text = $1->getnameofsymbol() + "," + $3->getnameofsymbol();
		outlog << "At line no: " << line_num << " arguments : arguments COMMA logic_expression " << endl << endl;
		outlog << text << endl << endl;
		$$ = new symbol_info(text, "arguments");
	}
	| logic_expression
	{
		outlog << "At line no: " << line_num << " arguments : logic_expression " << endl << endl;
		outlog << $1->getnameofsymbol() << endl << endl;
		$$ = new symbol_info($1->getnameofsymbol(), "arguments");
	}
	;

%%

int yyerror(const char *s)
{
	cout << "Syntax error at line " << line_num << endl;
	return 0;
}

int main(int c, char *v[])
{
	if (c != 2)
	{
		cout << "Provide input file name" << endl;
		return 0;
	}

	yyin = fopen(v[1], "r");
	outlog.open("22201884_log.txt", ios::trunc);

	if (yyin == NULL)
	{
		cout << "Couldn't open file" << endl;
		return 0;
	}

	yyparse();

	outlog << "Total lines: " << line_num << endl;

	outlog.close();
	fclose(yyin);

	return 0;
}