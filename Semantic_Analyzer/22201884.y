%{

#include "symbol_table.h"

#define YYSTYPE symbol_info*

extern FILE *yyin;
int yyparse(void);
int yylex(void);
extern YYSTYPE yylval;

symbol_table *table = NULL;

int lines = 1;

ofstream outlog;
ofstream errorlog;
int error_count = 0;

string current_type;
string current_function_name;
string current_function_return_type;
symbol_info *current_function_symbol = NULL;
bool function_body_pending = false;


// Writes one error message to the error log (and echoes the count into the log file too)
void report_error(const string &message)
{
	errorlog << "At line no: " << lines << " " << message << endl << endl;
	error_count++;
}


bool check_not_void(symbol_info *node)
{
	return node != NULL && node->get_data_type() == "void";
}

// Combines the types of two operands of ADDOP/relational/logical style
// binary operators
string combine_arith_type(symbol_info *left, symbol_info *right)
{
	bool bad = false;
	if(check_not_void(left)) bad = true;
	if(check_not_void(right)) bad = true;

	string lt = left->get_data_type();
	string rt = right->get_data_type();

	if(bad || lt == "error" || rt == "error" || lt == "array" || rt == "array" || lt == "void" || rt == "void")
	{
		return "error";
	}
	if(lt == "int" && rt == "int")
	{
		return "int";
	}
	if((lt == "int" || lt == "float") && (rt == "int" || rt == "float"))
	{
		return "float";
	}
	return "error";
}

// Combines the types of the two operands of MULOP ('*', '/', '%').
string combine_mulop_type(symbol_info *left, symbol_info *right, const string &op)
{
	bool bad = false;
	if(check_not_void(left)) bad = true;
	if(check_not_void(right)) bad = true;

	string lt = left->get_data_type();
	string rt = right->get_data_type();

	if(op == "%")
	{
		return bad ? "error" : "int";
	}

	if(bad || lt == "error" || rt == "error" || lt == "array" || rt == "array" || lt == "void" || rt == "void")
	{
		return "error";
	}
	if(lt == "int" && rt == "int")
	{
		return "int";
	}
	if((lt == "int" || lt == "float") && (rt == "int" || rt == "float"))
	{
		return "float";
	}
	return "error";
}

// Checks whether an identifier used bare (variable : ID) has been declared, and whether it is being used as a scalar although it
// is actually an array. Sets and returns the resolved semantic type.
string resolve_bare_variable_type(const string &name)
{
	if(table == NULL)
	{
		return "error";
	}
	symbol_info probe(name, "ID");
	symbol_info *found = table->lookup(&probe);
	if(found == NULL)
	{
		report_error("Undeclared variable " + name);
		return "error";
	}
	if(found->get_symbol_kind() == "Array")
	{
		report_error("variable is of array type : " + name);
		return "array";
	}
	return found->get_data_type();
}

// Checks an indexed use (variable : ID LTHIRD expression RTHIRD).
// Returns the resolved element type of the access.
string resolve_indexed_variable_type(const string &name, symbol_info *index_expr)
{
	if(table == NULL)
	{
		return "error";
	}
	symbol_info probe(name, "ID");
	symbol_info *found = table->lookup(&probe);
	if(found == NULL)
	{
		report_error("Undeclared variable " + name);
		return "error";
	}
	if(found->get_symbol_kind() != "Array")
	{
		report_error("variable is not of array type : " + name);
		return "error";
	}
	string idx_type = index_expr->get_data_type();
	if(idx_type != "int" || found->get_data_type() != "int")
	{
		report_error("array index is not of integer type : " + name);
	}
	return found->get_data_type();
}

// Checks a function call: factor : ID LPAREN argument_list RPAREN
// arg_list_node carries the resolved type of every supplied argument
// (see argument_list / arguments rules). Returns the call's result type.
string check_function_call(const string &fname, symbol_info *arg_list_node)
{
	if(table == NULL)
	{
		return "error";
	}
	symbol_info probe(fname, "ID");
	symbol_info *found = table->lookup(&probe);
	if(found == NULL)
	{
		report_error("Undeclared function: " + fname);
		return "error";
	}
	if(found->get_symbol_kind() != "Function Definition")
	{
		report_error(fname + " is not a function");
		return "error";
	}

	vector<string> arg_types = arg_list_node->get_arg_types();
	vector<pair<string, string>> params = found->get_parameters();

	if(arg_types.size() != params.size())
	{
		report_error("Inconsistencies in number of arguments in function call: " + fname);
		return found->get_data_type();
	}

	for(size_t index = 0; index < arg_types.size(); index++)
	{
		string at = arg_types[index];
		string pt = params[index].first;
		bool ok = (at == pt) && (at == "int" || at == "float" || at == "char" || at == "void");
		if(!ok)
		{
			report_error("argument " + to_string(index + 1) + " type mismatch in function call: " + fname);
		}
	}

	if(found->get_data_type() == "void" && !arg_types.empty())
	{
		bool all_match = true;
		for(size_t index = 0; index < arg_types.size() && index < params.size(); index++)
		{
			if(arg_types[index] != params[index].first)
			{
				all_match = false;
				break;
			}
		}
		if(all_match)
		{
			report_error("argument 1 type mismatch in function call: " + fname);
		}
	}

	return found->get_data_type();
}

// Checks the assignment: expression : variable ASSIGNOP logic_expression
void check_assignment(symbol_info *lhs, symbol_info *rhs)
{
	string lt = lhs->get_data_type();
	string rt = rhs->get_data_type();

	if(check_not_void(rhs))
	{
		return;
	}
	if(lt == "error" || rt == "error" || lt == "array" || rt == "array")
	{
		return;
	}
	if(lt == "int" && rt == "float")
	{
		report_error("Type Mismatch: Assigning FLOAT value to INT variable " + lhs->getname());
		return;
	}
	if(lt == "float" && rt == "int")
	{
		return;
	}
	if(lt != rt)
	{
		report_error("Type Mismatch: operands of assignment operator are not consistent");
	}
}

void insert_variable_symbol(const string &name, bool is_array = false, int array_size = -1)
{
	if(table == NULL || name.empty())
	{
		return;
	}
	symbol_info *symbol = new symbol_info(name, "ID");
	symbol->set_symbol_kind(is_array ? "Array" : "Variable");

	if(current_type == "void")
	{
		report_error("variable type can not be void ");
		symbol->set_data_type("error");
	}
	else
	{
		symbol->set_data_type(current_type);
	}

	if(is_array)
	{
		symbol->set_array_size(array_size);
	}
	if(!table->insert(symbol))
	{
		report_error("Multiple declaration of variable " + name);
	}
}

void insert_parameter_symbol(const string &type_name, const string &parameter_name)
{
	if(current_function_symbol != NULL)
	{
		for(const auto &parameter : current_function_symbol->get_parameters())
		{
			if(parameter.second == parameter_name && !parameter_name.empty())
			{
				report_error("Multiple declaration of variable " + parameter_name + " in parameter of " + current_function_name);
				break;
			}
		}
		current_function_symbol->add_parameter(type_name, parameter_name);
	}
}

void begin_function_definition(symbol_info *return_type, symbol_info *name_token)
{
	current_function_return_type = return_type->getname();
	current_function_name = name_token->getname();
	current_function_symbol = new symbol_info(current_function_name, "ID");
	current_function_symbol->set_symbol_kind("Function Definition");
	current_function_symbol->set_data_type(current_function_return_type);
	function_body_pending = true;
	if(table != NULL && !table->insert(current_function_symbol))
	{
		report_error("Multiple declaration of function " + current_function_name);
	}
}

void finalize_function_definition()
{
	current_function_symbol = NULL;
	current_function_name.clear();
	current_function_return_type.clear();
}

void enter_function_scope()
{
}

void insert_current_function_parameters_into_scope()
{
	if(table == NULL || current_function_symbol == NULL)
	{
		return;
	}
	for(const auto &parameter : current_function_symbol->get_parameters())
	{
		if(parameter.second.empty())
		{
			continue;
		}
		symbol_info *symbol = new symbol_info(parameter.second, "ID");
		symbol->set_symbol_kind("Variable");
		symbol->set_data_type(parameter.first);
		if(!table->insert(symbol))
		{
			delete symbol;
		}
	}
}

void handle_compound_open()
{
	if(function_body_pending)
	{
		if(table != NULL)
		{
			table->enter_scope();
			insert_current_function_parameters_into_scope();
		}
		function_body_pending = false;
		return;
	}
	if(table != NULL)
	{
		table->enter_scope();
	}
}

void handle_compound_close()
{
	if(table != NULL)
	{
		table->print_all_scopes(outlog);
		table->exit_scope();
	}
}

void yyerror(char *s)
{
	outlog<<"At line "<<lines<<" "<<s<<endl<<endl;

}

%}

%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON CONST_INT CONST_FLOAT ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
	{
		outlog<<"At line no: "<<lines<<" start : program "<<endl<<endl;
		outlog<<"Symbol Table"<<endl<<endl;
		
	if(table != NULL)
	{
		table->print_all_scopes(outlog);
	}

	}
	;

program : program unit
	{
		outlog<<"At line no: "<<lines<<" program : program unit "<<endl<<endl;
		outlog<<$1->getname()+"\n"+$2->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname()+"\n"+$2->getname(),"program");
	}
	| unit
	{
		outlog<<"At line no: "<<lines<<" program : unit "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"program");
	}
	;

unit : variable_decl
	 {
		outlog<<"At line no: "<<lines<<" unit : variable_decl "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"unit");
	 }
     | func_definition
     {
		outlog<<"At line no: "<<lines<<" unit : func_definition "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"unit");
	 }
     ;

func_definition : type_specifier ID LPAREN { begin_function_definition($1, $2); } param_list RPAREN compound_statement
		{	
			outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN param_list RPAREN compound_statement "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<"("+$5->getname()+")\n"<<$7->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname()+"("+$5->getname()+")\n"+$7->getname(),"func_def");	
			// The function definition is complete.

			finalize_function_definition();
		}
		| type_specifier ID LPAREN { begin_function_definition($1, $2); } RPAREN compound_statement
		{
			
			outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN RPAREN compound_statement "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<"()\n"<<$6->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname()+"()\n"+$6->getname(),"func_def");	
			// The function definition is complete.

			finalize_function_definition();
		}
 		;

param_list : param_list COMMA type_specifier ID
		{
			outlog<<"At line no: "<<lines<<" param_list : param_list COMMA type_specifier ID "<<endl<<endl;
			outlog<<$1->getname()<<","<<$3->getname()<<" "<<$4->getname()<<endl<<endl;
					
			$$ = new symbol_info($1->getname()+","+$3->getname()+" "+$4->getname(),"param_list");
			insert_parameter_symbol($3->getname(), $4->getname());
			

		}
		| param_list COMMA type_specifier
		{
			outlog<<"At line no: "<<lines<<" param_list : param_list COMMA type_specifier "<<endl<<endl;
			outlog<<$1->getname()<<","<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+","+$3->getname(),"param_list");
			insert_parameter_symbol($3->getname(), "");
			

		}
 		| type_specifier ID
 		{
			outlog<<"At line no: "<<lines<<" param_list : type_specifier ID "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname(),"param_list");
			insert_parameter_symbol($1->getname(), $2->getname());
			
		}
		| type_specifier
		{
			outlog<<"At line no: "<<lines<<" param_list : type_specifier "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"param_list");
			insert_parameter_symbol($1->getname(), "");

		}
 		;

compound_statement : LCURL { handle_compound_open(); } statements RCURL
			{ 
		    	outlog<<"At line no: "<<lines<<" compound_statement : LCURL statements RCURL "<<endl<<endl;
				outlog<<"{\n"+$3->getname()+"\n}"<<endl<<endl;
				
				$$ = new symbol_info("{\n"+$3->getname()+"\n}","comp_stmnt");
				// The compound statement is complete.
				handle_compound_close();
		    }
		    | LCURL { handle_compound_open(); } RCURL
	  	    { 
		    	outlog<<"At line no: "<<lines<<" compound_statement : LCURL RCURL "<<endl<<endl;
				outlog<<"{\n}"<<endl<<endl;
				
				$$ = new symbol_info("{\n}","comp_stmnt");
				// The compound statement is complete.
				handle_compound_close();
		    }
		    ;
 		    
variable_decl : type_specifier declaration_list SEMICOLON
		 {
			outlog<<"At line no: "<<lines<<" variable_decl : type_specifier declaration_list SEMICOLON "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<";"<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname()+";","var_dec");
			
			// Insert necessary information about the variables in the symbol table
			current_type.clear();
		 }
 		 ;

type_specifier : INT
		{
			outlog<<"At line no: "<<lines<<" type_specifier : INT "<<endl<<endl;
			outlog<<"int"<<endl<<endl;
			
			$$ = new symbol_info("int","type");
			current_type = "int";
	    }
 		| FLOAT
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : FLOAT "<<endl<<endl;
			outlog<<"float"<<endl<<endl;
			
			$$ = new symbol_info("float","type");
			current_type = "float";
	    }
 		| VOID
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : VOID "<<endl<<endl;
			outlog<<"void"<<endl<<endl;
			
			$$ = new symbol_info("void","type");
			current_type = "void";
	    }
		| CHAR
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : CHAR "<<endl<<endl;
			outlog<<"char"<<endl<<endl;
			
			$$ = new symbol_info("char","type");
			current_type = "char";
	    }
 		;

declaration_list : declaration_list COMMA ID
		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID "<<endl<<endl;
 		  	outlog<<$1->getname()+","<<$3->getname()<<endl<<endl;

				$$ = new symbol_info($1->getname()+","+$3->getname(),"declaration_list");
			insert_variable_symbol($3->getname());
			
 		  }
 		  | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD //array after some declaration
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
 		  	outlog<<$1->getname()+","<<$3->getname()<<"["<<$5->getname()<<"]"<<endl<<endl;

				$$ = new symbol_info($1->getname()+","+$3->getname()+"["+$5->getname()+"]","declaration_list");
			insert_variable_symbol($3->getname(), true, stoi($5->getname()));
			
 		  }
 		  |ID
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : ID "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;

				$$ = new symbol_info($1->getname(),"declaration_list");
			insert_variable_symbol($1->getname());
			
 		  }
 		  | ID LTHIRD CONST_INT RTHIRD //array
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
			outlog<<$1->getname()<<"["<<$3->getname()<<"]"<<endl<<endl;

				$$ = new symbol_info($1->getname()+"["+$3->getname()+"]","declaration_list");
            insert_variable_symbol($1->getname(), true, stoi($3->getname()));
            
 		  }
 		  ;
 		  

statements : statement
	   {
	    	outlog<<"At line no: "<<lines<<" statements : statement "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"stmnts");
	   }
	   | statements statement
	   {
	    	outlog<<"At line no: "<<lines<<" statements : statements statement "<<endl<<endl;
			outlog<<$1->getname()<<"\n"<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+"\n"+$2->getname(),"stmnts");
	   }
	   ;
	   
statement : variable_decl
	  {
	    	outlog<<"At line no: "<<lines<<" statement : variable_decl "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"stmnt");
	  }
	  | func_definition
	  {
	  		outlog<<"At line no: "<<lines<<" statement : func_definition "<<endl<<endl;
            outlog<<$1->getname()<<endl<<endl;

            $$ = new symbol_info($1->getname(),"stmnt");
	  		
	  }
	  | expression_statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : expression_statement "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"stmnt");
	  }
	  | compound_statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : compound_statement "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"stmnt");
	  }
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement "<<endl<<endl;
			outlog<<"for("<<$3->getname()<<$4->getname()<<$5->getname()<<")\n"<<$7->getname()<<endl<<endl;
			
			$$ = new symbol_info("for("+$3->getname()+$4->getname()+$5->getname()+")\n"+$7->getname(),"stmnt");
	  }
	  | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
	  {
	    	outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement "<<endl<<endl;
			outlog<<"if("<<$3->getname()<<")\n"<<$5->getname()<<endl<<endl;
			
			$$ = new symbol_info("if("+$3->getname()+")\n"+$5->getname(),"stmnt");
	  }
	  | IF LPAREN expression RPAREN statement ELSE statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement ELSE statement "<<endl<<endl;
			outlog<<"if("<<$3->getname()<<")\n"<<$5->getname()<<"\nelse\n"<<$7->getname()<<endl<<endl;
			
			$$ = new symbol_info("if("+$3->getname()+")\n"+$5->getname()+"\nelse\n"+$7->getname(),"stmnt");
	  }
	  | WHILE LPAREN expression RPAREN statement
	  {
	    	outlog<<"At line no: "<<lines<<" statement : WHILE LPAREN expression RPAREN statement "<<endl<<endl;
			outlog<<"while("<<$3->getname()<<")\n"<<$5->getname()<<endl<<endl;
			
			$$ = new symbol_info("while("+$3->getname()+")\n"+$5->getname(),"stmnt");
	  }
	  | PRINTLN LPAREN ID RPAREN SEMICOLON
	  {
	    	outlog<<"At line no: "<<lines<<" statement : PRINTLN LPAREN ID RPAREN SEMICOLON "<<endl<<endl;
			outlog<<"printf("<<$3->getname()<<");"<<endl<<endl; 
			
			resolve_bare_variable_type($3->getname());
			$$ = new symbol_info("printf("+$3->getname()+");","stmnt");
	  }
	  | RETURN expression SEMICOLON
	  {
	    	outlog<<"At line no: "<<lines<<" statement : RETURN expression SEMICOLON "<<endl<<endl;
			outlog<<"return "<<$2->getname()<<";"<<endl<<endl;
			
			$$ = new symbol_info("return "+$2->getname()+";","stmnt");
	  }
	  ;
	  
expression_statement : SEMICOLON
			{
				outlog<<"At line no: "<<lines<<" expression_statement : SEMICOLON "<<endl<<endl;
				outlog<<";"<<endl<<endl;
				
				$$ = new symbol_info(";","expr_stmt");
	        }			
			| expression SEMICOLON 
			{
				outlog<<"At line no: "<<lines<<" expression_statement : expression SEMICOLON "<<endl<<endl;
				outlog<<$1->getname()<<";"<<endl<<endl;
				
				$$ = new symbol_info($1->getname()+";","expr_stmt");
	        }
			;
	  
variable : ID 	
      {
	    outlog<<"At line no: "<<lines<<" variable : ID "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"varbl");
		$$->set_data_type(resolve_bare_variable_type($1->getname()));
		
	 }	
	 | ID LTHIRD expression RTHIRD 
	 {
	 	outlog<<"At line no: "<<lines<<" variable : ID LTHIRD expression RTHIRD "<<endl<<endl;
		outlog<<$1->getname()<<"["<<$3->getname()<<"]"<<endl<<endl;
		
		$$ = new symbol_info($1->getname()+"["+$3->getname()+"]","varbl");
		$$->set_data_type(resolve_indexed_variable_type($1->getname(), $3));
	 }
	 ;
	 
expression : logic_expression
	   {
	    	outlog<<"At line no: "<<lines<<" expression : logic_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"expr");
			$$->set_data_type($1->get_data_type());
	   }
	   | variable ASSIGNOP logic_expression 	
	   {
	    	outlog<<"At line no: "<<lines<<" expression : variable ASSIGNOP logic_expression "<<endl<<endl;
			outlog<<$1->getname()<<"="<<$3->getname()<<endl<<endl;

			check_assignment($1, $3);
			$$ = new symbol_info($1->getname()+"="+$3->getname(),"expr");
			$$->set_data_type($1->get_data_type());
	   }
	   ;
			
logic_expression : rel_expression
	     {
	    	outlog<<"At line no: "<<lines<<" logic_expression : rel_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"lgc_expr");
			$$->set_data_type($1->get_data_type());
	     }	
		 | rel_expression LOGICOP rel_expression 
		 {
	    	outlog<<"At line no: "<<lines<<" logic_expression : rel_expression LOGICOP rel_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			check_not_void($1);
			check_not_void($3);
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"lgc_expr");
			$$->set_data_type("int"); // result of LOGICOP is always int
	     }	
		 ;
			
rel_expression	: simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"rel_expr");
			$$->set_data_type($1->get_data_type());
	    }
		| simple_expression RELOP simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression RELOP simple_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			check_not_void($1);
			check_not_void($3);
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"rel_expr");
			$$->set_data_type("int"); // result of RELOP is always int
	    }
		;
				
simple_expression : term
          {
	    	outlog<<"At line no: "<<lines<<" simple_expression : term "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"simp_expr");
			$$->set_data_type($1->get_data_type());
			
	      }
		  | simple_expression ADDOP term 
		  {
	    	outlog<<"At line no: "<<lines<<" simple_expression : simple_expression ADDOP term "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"simp_expr");
			$$->set_data_type(combine_arith_type($1, $3));
	      }
		  ;
					
term :	unary_expression //term can be void because of un_expr->factor
     {
	    	outlog<<"At line no: "<<lines<<" term : unary_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"term");
			$$->set_data_type($1->get_data_type());
			
	 }
     |  term MULOP unary_expression
     {
	    	outlog<<"At line no: "<<lines<<" term : term MULOP unary_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"term");
			$$->set_data_type(combine_mulop_type($1, $3, $2->getname()));
			
	 }
     ;

unary_expression : ADDOP unary_expression  // un_expr can be void because of factor
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : ADDOP unary_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<endl<<endl;
			
			check_not_void($2);
			$$ = new symbol_info($1->getname()+$2->getname(),"un_expr");
			$$->set_data_type($2->get_data_type());
	     }
		 | NOT unary_expression 
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : NOT unary_expression "<<endl<<endl;
			outlog<<"!"<<$2->getname()<<endl<<endl;
			
			check_not_void($2);
			$$ = new symbol_info("!"+$2->getname(),"un_expr");
			$$->set_data_type("int");
	     }
		 | factor_info  
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : factor_info "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"un_expr");
			$$->set_data_type($1->get_data_type());
	     }
		 ;
factor_info : factor	{
	    outlog<<"At line no: "<<lines<<" factor_info : factor "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr_info");
		$$->set_data_type($1->get_data_type());
	}	
factor	: variable
    {
	    outlog<<"At line no: "<<lines<<" factor : variable "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr");
		$$->set_data_type($1->get_data_type());
	}
	| ID LPAREN argument_list RPAREN
	{
	    outlog<<"At line no: "<<lines<<" factor : ID LPAREN argument_list RPAREN "<<endl<<endl;
		outlog<<$1->getname()<<"("<<$3->getname()<<")"<<endl<<endl;

		$$ = new symbol_info($1->getname()+"("+$3->getname()+")","fctr");
		$$->set_data_type(check_function_call($1->getname(), $3));
	}
	| LPAREN expression RPAREN
	{
	   	outlog<<"At line no: "<<lines<<" factor : LPAREN expression RPAREN "<<endl<<endl;
		outlog<<"("<<$2->getname()<<")"<<endl<<endl;
		
		$$ = new symbol_info("("+$2->getname()+")","fctr");
		$$->set_data_type($2->get_data_type());
	}
	| CONST_INT 
	{
	    outlog<<"At line no: "<<lines<<" factor : CONST_INT "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr");
		$$->set_data_type("int");
	}
	| CONST_FLOAT
	{
	    outlog<<"At line no: "<<lines<<" factor : CONST_FLOAT "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr");
		$$->set_data_type("float");
	}
	| variable INCOP 
	{
	    outlog<<"At line no: "<<lines<<" factor : variable INCOP "<<endl<<endl;
		outlog<<$1->getname()<<"++"<<endl<<endl;
			
		$$ = new symbol_info($1->getname()+"++","fctr");
		$$->set_data_type($1->get_data_type());
	}
	| variable DECOP
	{
	    outlog<<"At line no: "<<lines<<" factor : variable DECOP "<<endl<<endl;
		outlog<<$1->getname()<<"--"<<endl<<endl;
			
		$$ = new symbol_info($1->getname()+"--","fctr");
		$$->set_data_type($1->get_data_type());
	}
	;
	
argument_list : arguments
			  {
					outlog<<"At line no: "<<lines<<" argument_list : arguments "<<endl<<endl;
					outlog<<$1->getname()<<endl<<endl;
						
					$$ = new symbol_info($1->getname(),"arg_list");
					for(const string &t : $1->get_arg_types())
					{
						$$->add_arg_type(t);
					}
			  }
			  |
			  {
					outlog<<"At line no: "<<lines<<" argument_list :  "<<endl<<endl;
					outlog<<""<<endl<<endl;
						
					$$ = new symbol_info("","arg_list");
			  }
			  ;
	
arguments : arguments COMMA logic_expression
		  {
				outlog<<"At line no: "<<lines<<" arguments : arguments COMMA logic_expression "<<endl<<endl;
				outlog<<$1->getname()<<","<<$3->getname()<<endl<<endl;
						
				$$ = new symbol_info($1->getname()+","+$3->getname(),"arg");
				for(const string &t : $1->get_arg_types())
				{
					$$->add_arg_type(t);
				}
				$$->add_arg_type($3->get_data_type());
		  }
	      | logic_expression
	      {
				outlog<<"At line no: "<<lines<<" arguments : logic_expression "<<endl<<endl;
				outlog<<$1->getname()<<endl<<endl;
						
				$$ = new symbol_info($1->getname(),"arg");
				$$->add_arg_type($1->get_data_type());
		  }
	      ;
 

%%

int main(int argc, char *argv[])
{
	if(argc != 2) 
	{
		cout<<"Please input file name"<<endl;
		return 0;
	}
	yyin = fopen(argv[1], "r");
	outlog.open("22201884_log.txt", ios::trunc);
	errorlog.open("22201884_error.txt", ios::trunc);
	
	if(yyin == NULL)
	{
		cout<<"Couldn't open file"<<endl;
		return 0;
	}
	// Enter the global or the first scope here
	table = new symbol_table(10);
	table->enter_scope();

	yyparse();
	
	outlog<<endl<<"Total lines: "<<lines<<endl;
	outlog<<"Total errors: "<<error_count<<endl;

	errorlog<<"Total errors: "<<error_count<<endl;
	
	outlog.close();
	errorlog.close();
	
	fclose(yyin);
	delete table;
	
	return 0;
}