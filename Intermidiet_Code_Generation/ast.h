#ifndef AST_H
#define AST_H

#include <iostream>
#include <vector>
#include <string>
#include <fstream>
#include <map>

using namespace std;

class ASTNode {
public:
    virtual ~ASTNode() {}
    virtual string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp, int& temp_count, int& label_count) const = 0;
};

// Expression node types

class ExprNode : public ASTNode {
protected:
    string node_type; // Type information (int, float, void, etc.)
public:
    ExprNode(string type) : node_type(type) {}
    virtual string get_type() const { return node_type; }
};

// Variable node (for ID references)

class VarNode : public ExprNode {
private:
    string name;
    ExprNode* index; // For array access, nullptr for simple variables

public:
    VarNode(string name, string type, ExprNode* idx = nullptr)
        : ExprNode(type), name(name), index(idx) {}
    
    ~VarNode() { if(index) delete index; }
    
    bool has_index() const { return index != nullptr; }
    
    string generate_index_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                              int& temp_count, int& label_count) const {
        // Generate code to calculate the array index and return the temp variable
        if (index) {
            return index->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        return "";
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for variable access or array access.
        // Compute the index temp first (if any) so temp numbers stay in
        // natural increasing order: index temp, then the read result temp.
        if (index) {
            string idx_temp = generate_index_code(outcode, symbol_to_temp, temp_count, label_count);
            string temp = "t" + to_string(temp_count++);
            outcode << temp << " = " << name << "[" << idx_temp << "]" << endl;
            return temp;
        } else {
            // Reserve a temp number as if a load were being generated,
            // then decide whether to actually emit it: if a temp
            // already holds this variable's current value, reuse that
            // one and discard the just-reserved number (this mirrors
            // the reference numbering, which leaves a gap where a
            // redundant load would have been).
            string temp = "t" + to_string(temp_count++);
            auto it = symbol_to_temp.find(name);
            if (it != symbol_to_temp.end()) {
                return it->second;
            }
            outcode << temp << " = " << name << endl;
            symbol_to_temp[name] = temp;
            return temp;
        }
    }
    
    string get_name() const { return name; }
};

// Constant node

class ConstNode : public ExprNode {
private:
    string value;

public:
    ConstNode(string val, string type) : ExprNode(type), value(val) {}
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for constant values
        string temp = "t" + to_string(temp_count++);
        outcode << temp << " = " << value << endl;
        return temp;
    }
};

// Binary operation node

class BinaryOpNode : public ExprNode {
private:
    string op;
    ExprNode* left;
    ExprNode* right;

public:
    BinaryOpNode(string op, ExprNode* left, ExprNode* right, string result_type)
        : ExprNode(result_type), op(op), left(left), right(right) {}
    
    ~BinaryOpNode() {
        delete left;
        delete right;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for binary operations
        string l = left->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string r = right->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string temp = "t" + to_string(temp_count++);
        outcode << temp << " = " << l << " " << op << " " << r << endl;
        return temp;
    }
};

// Unary operation node

class UnaryOpNode : public ExprNode {
private:
    string op;
    ExprNode* expr;

public:
    UnaryOpNode(string op, ExprNode* expr, string result_type)
        : ExprNode(result_type), op(op), expr(expr) {}
    
    ~UnaryOpNode() { delete expr; }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for unary operations
        string e = expr->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string temp = "t" + to_string(temp_count++);
        outcode << temp << " = " << op << e << endl;
        return temp;
    }
};

// Assignment node

class AssignNode : public ExprNode {
private:
    VarNode* lhs;
    ExprNode* rhs;

public:
    AssignNode(VarNode* lhs, ExprNode* rhs, string result_type)
        : ExprNode(result_type), lhs(lhs), rhs(rhs) {}
    
    ~AssignNode() {
        delete lhs;
        delete rhs;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for assignment operations
        string rhs_temp = rhs->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        if (lhs->has_index()) {
            string idx_temp = lhs->generate_index_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << lhs->get_name() << "[" << idx_temp << "] = " << rhs_temp << endl;
            // Array elements aren't tracked individually, so an indexed
            // write can't safely update a whole-variable cache entry.
        } else {
            outcode << lhs->get_name() << " = " << rhs_temp << endl;
            // The variable's current value now lives in rhs_temp, so
            // future reads of it can reuse rhs_temp directly.
            symbol_to_temp[lhs->get_name()] = rhs_temp;
        }
        return rhs_temp;
    }
};

// Statement node types

class StmtNode : public ASTNode {
public:
    virtual string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                                int& temp_count, int& label_count) const = 0;
};

// Expression statement node

class ExprStmtNode : public StmtNode {
private:
    ExprNode* expr;

public:
    ExprStmtNode(ExprNode* e) : expr(e) {}
    ~ExprStmtNode() { if(expr) delete expr; }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for expression statements.
        // NOTE: return the inner expression's result temp (instead of "")
        // because the grammar's FOR rule builds its init/condition parts
        // from "expression_statement", so ForNode ends up holding
        // ExprStmtNode objects (cast to ExprNode*) for init/condition.
        // Propagating the temp here lets ForNode read the condition's
        // value correctly; for ordinary use as a plain statement in a
        // BlockNode, the returned value is simply unused/ignored.
        if (expr) {
            return expr->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        return "";
    }
};

// Block (compound statement) node

class BlockNode : public StmtNode {
private:
    vector<StmtNode*> statements;

public:
    ~BlockNode() {
        for (auto stmt : statements) {
            delete stmt;
        }
    }
    
    void add_statement(StmtNode* stmt) {
        if (stmt) statements.push_back(stmt);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for all statements in the block
        for (auto stmt : statements) {
            if (stmt) stmt->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        return "";
    }
};

// If statement node

class IfNode : public StmtNode {
private:
    ExprNode* condition;
    StmtNode* then_block;
    StmtNode* else_block; // nullptr if no else part

public:
    IfNode(ExprNode* cond, StmtNode* then_stmt, StmtNode* else_stmt = nullptr)
        : condition(cond), then_block(then_stmt), else_block(else_stmt) {}
    
    ~IfNode() {
        delete condition;
        delete then_block;
        if (else_block) delete else_block;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for if-else statements
        string cond_temp = condition->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string L_true = "L" + to_string(label_count++);
        if (else_block) {
            string L_false = "L" + to_string(label_count++);
            string L_end = "L" + to_string(label_count++);
            outcode << "if " << cond_temp << " goto " << L_true << endl;
            outcode << "goto " << L_false << endl;
            outcode << L_true << ":" << endl;
            then_block->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << "goto " << L_end << endl;
            outcode << L_false << ":" << endl;
            else_block->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << L_end << ":" << endl;
        } else {
            string L_false = "L" + to_string(label_count++);
            string L_end = "L" + to_string(label_count++);
            outcode << "if " << cond_temp << " goto " << L_true << endl;
            outcode << "goto " << L_false << endl;
            outcode << L_true << ":" << endl;
            then_block->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << "goto " << L_end << endl;
            outcode << L_false << ":" << endl;
            outcode << L_end << ":" << endl;
        }
        return "";
    }
};

// While statement node

class WhileNode : public StmtNode {
private:
    ExprNode* condition;
    StmtNode* body;

public:
    WhileNode(ExprNode* cond, StmtNode* body_stmt)
        : condition(cond), body(body_stmt) {}
    
    ~WhileNode() {
        delete condition;
        delete body;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for while loops
        string L_start = "L" + to_string(label_count++);
        string L_true = "L" + to_string(label_count++);
        string L_end = "L" + to_string(label_count++);
        outcode << L_start << ":" << endl;
        string cond_temp = condition->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        outcode << "if " << cond_temp << " goto " << L_true << endl;
        outcode << "goto " << L_end << endl;
        outcode << L_true << ":" << endl;
        body->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        outcode << "goto " << L_start << endl;
        outcode << L_end << ":" << endl;
        return "";
    }
};

// For statement node

class ForNode : public StmtNode {
private:
    ExprNode* init;
    ExprNode* condition;
    ExprNode* update;
    StmtNode* body;

public:
    ForNode(ExprNode* init_expr, ExprNode* cond_expr, ExprNode* update_expr, StmtNode* body_stmt)
        : init(init_expr), condition(cond_expr), update(update_expr), body(body_stmt) {}
    
    ~ForNode() {
        if (init) delete init;
        if (condition) delete condition;
        if (update) delete update;
        delete body;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for for loops
        if (init) init->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        // The loop body/update can change variables used in the
        // condition on later iterations, so the pre-loop cached value
        // can't be trusted for the condition check: clear the cache
        // before generating it.
        symbol_to_temp.clear();
        string L_start = "L" + to_string(label_count++);
        string L_true = "L" + to_string(label_count++);
        string L_end = "L" + to_string(label_count++);
        outcode << L_start << ":" << endl;
        if (condition) {
            string cond_temp = condition->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << "if " << cond_temp << " goto " << L_true << endl;
            outcode << "goto " << L_end << endl;
        }
        outcode << L_true << ":" << endl;
        body->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        if (update) update->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        outcode << "goto " << L_start << endl;
        outcode << L_end << ":" << endl;
        return "";
    }
};

// Return statement node

class ReturnNode : public StmtNode {
private:
    ExprNode* expr;

public:
    ReturnNode(ExprNode* e) : expr(e) {}
    ~ReturnNode() { if (expr) delete expr; }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for return statements
        if (expr) {
            string temp = expr->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << "return " << temp << endl;
        } else {
            outcode << "return" << endl;
        }
        return "";
    }
};

// Declaration node

class DeclNode : public StmtNode {
private:
    string type;
    vector<pair<string, int>> vars; // Variable name and array size (0 for regular vars)

public:
    DeclNode(string t) : type(t) {}
    
    void add_var(string name, int array_size = 0) {
        vars.push_back(make_pair(name, array_size));
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for variable declarations (as comments)
        for (const auto& v : vars) {
            if (v.second == 0) {
                outcode << "// Declaration: " << type << " " << v.first << endl;
            } else {
                outcode << "// Declaration: " << type << " " << v.first << "[" << v.second << "]" << endl;
            }
        }
        return "";
    }
    
    string get_type() const { return type; }
    const vector<pair<string, int>>& get_vars() const { return vars; }
};

// Function declaration node

class FuncDeclNode : public ASTNode {
private:
    string return_type;
    string name;
    vector<pair<string, string>> params; // Parameter type and name
    BlockNode* body;

public:
    FuncDeclNode(string ret_type, string n) : return_type(ret_type), name(n), body(nullptr) {}
    ~FuncDeclNode() { if (body) delete body; }
    
    void add_param(string type, string name) {
        params.push_back(make_pair(type, name));
    }
    
    void set_body(BlockNode* b) {
        body = b;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for function declarations
        string param_str = "";
        for (size_t i = 0; i < params.size(); i++) {
            param_str += params[i].first + " " + params[i].second;
            if (i != params.size() - 1) param_str += ", ";
        }
        outcode << "// Function: " << return_type << " " << name << "(" << param_str << ")" << endl;
        // Each function starts a fresh scope: clear any cached
        // variable->temp mappings left over from a previous function,
        // since those temps no longer hold valid values here.
        symbol_to_temp.clear();
        if (body) {
            body->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        outcode << endl;
        return "";
    }
};

// Helper class for function arguments

class ArgumentsNode : public ASTNode {
private:
    vector<ExprNode*> args;

public:
    ~ArgumentsNode() {
        // Don't delete args here - they'll be transferred to FuncCallNode
    }
    
    void add_argument(ExprNode* arg) {
        if (arg) args.push_back(arg);
    }
    
    ExprNode* get_argument(int index) const {
        if (index >= 0 && index < args.size()) {
            return args[index];
        }
        return nullptr;
    }
    
    size_t size() const {
        return args.size();
    }
    
    const vector<ExprNode*>& get_arguments() const {
        return args;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // This node doesn't generate code directly
        return "";
    }
};

// Function call node

class FuncCallNode : public ExprNode {
private:
    string func_name;
    vector<ExprNode*> arguments;

public:
    FuncCallNode(string name, string result_type)
        : ExprNode(result_type), func_name(name) {}
    
    ~FuncCallNode() {
        for (auto arg : arguments) {
            delete arg;
        }
    }
    
    void add_argument(ExprNode* arg) {
        if (arg) arguments.push_back(arg);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for function calls
        for (auto arg : arguments) {
            string arg_temp;
            VarNode* var_arg = dynamic_cast<VarNode*>(arg);
            if (var_arg && !var_arg->has_index()) {
                // Call arguments are always materialized into a fresh
                // temp, even if the variable's value is already cached,
                // matching calling-convention semantics.
                arg_temp = "t" + to_string(temp_count++);
                outcode << arg_temp << " = " << var_arg->get_name() << endl;
                symbol_to_temp[var_arg->get_name()] = arg_temp;
            } else {
                arg_temp = arg->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            }
            outcode << "param " << arg_temp << endl;
        }
        string temp = "t" + to_string(temp_count++);
        outcode << temp << " = call " << func_name << ", " << arguments.size() << endl;
        return temp;
    }
};

// Program node (root of AST)

class ProgramNode : public ASTNode {
private:
    vector<ASTNode*> units;

public:
    ~ProgramNode() {
        for (auto unit : units) {
            delete unit;
        }
    }
    
    void add_unit(ASTNode* unit) {
        if (unit) units.push_back(unit);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Generate code for the entire program
        for (auto unit : units) {
            if (unit) unit->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        return "";
    }
};

#endif // AST_H