#include "scope_table.h"

extern ofstream outlog;

class symbol_table
{
private:
    scope_table *current_scope;
    int bucket_count;
    int current_scope_id;

public:
    symbol_table(int bucket_count);
    ~symbol_table();
    void enter_scope();
    void exit_scope();
    bool insert(symbol_info* symbol);
    symbol_info* lookup(symbol_info* symbol);
    void print_current_scope();
    void print_all_scopes(ofstream& outlog);
 
};

// complete the methods of symbol_table class
inline symbol_table::symbol_table(int bucket_count)
{
    this->bucket_count = bucket_count;
    this->current_scope_id = 0;
    current_scope = NULL;
}

inline symbol_table::~symbol_table()
{
    while(current_scope != NULL)
    {
        scope_table *parent_scope = current_scope->get_parent_scope();
        delete current_scope;
        current_scope = parent_scope;
    }
}

inline void symbol_table::enter_scope()
{
    current_scope = new scope_table(bucket_count, ++current_scope_id, current_scope);
    outlog << "New ScopeTable with ID " << current_scope->get_unique_id() << " created" << endl << endl;
}

inline void symbol_table::exit_scope()
{
    if(current_scope == NULL)
    {
        return;
    }
    outlog << "Scopetable with ID " << current_scope->get_unique_id() << " removed" << endl << endl;
    scope_table *parent_scope = current_scope->get_parent_scope();
    delete current_scope;
    current_scope = parent_scope;
}

inline bool symbol_table::insert(symbol_info* symbol)
{
    if(current_scope == NULL)
    {
        return false;
    }
    return current_scope->insert_in_scope(symbol);
}

inline symbol_info* symbol_table::lookup(symbol_info* symbol)
{
    scope_table *scope = current_scope;
    while(scope != NULL)
    {
        symbol_info *found = scope->lookup_in_scope(symbol);
        if(found != NULL)
        {
            return found;
        }
        scope = scope->get_parent_scope();
    }
    return NULL;
}

inline void symbol_table::print_current_scope()
{
    if(current_scope != NULL)
    {
        current_scope->print_scope_table(outlog);
    }
}

inline void symbol_table::print_all_scopes(ofstream& outlog)
{
    outlog << "################################" << endl << endl;
    scope_table *temp = current_scope;
    while(temp != NULL)
    {
        temp->print_scope_table(outlog);
        temp = temp->get_parent_scope();
        if(temp != NULL)
        {
            outlog << endl;
        }
    }
    outlog << "################################" << endl << endl;
}
