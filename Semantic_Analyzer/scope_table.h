#include "symbol_info.h"

extern ofstream outlog;

class scope_table
{
private:
    int bucket_count;
    int unique_id;
    scope_table *parent_scope = NULL;
    vector<list<symbol_info *>> table;

    int hash_function(string name)
    {
        if(bucket_count <= 0)
        {
            return 0;
        }
        unsigned long long hash_value = 0;
        for(char ch : name)
        {
            hash_value += (unsigned char)ch;
        }
        return (int)(hash_value % bucket_count);
    }

public:
    scope_table() : scope_table(10, 1, NULL) {}
    scope_table(int bucket_count, int unique_id, scope_table *parent_scope);
    scope_table *get_parent_scope();
    int get_unique_id();
    symbol_info *lookup_in_scope(symbol_info* symbol);
    bool insert_in_scope(symbol_info* symbol);
    bool delete_from_scope(symbol_info* symbol);
    void print_scope_table(ofstream& outlog);
    ~scope_table();

};

// complete the methods of scope_table class
inline scope_table::scope_table(int bucket_count, int unique_id, scope_table *parent_scope)
{
    this->bucket_count = bucket_count;
    this->unique_id = unique_id;
    this->parent_scope = parent_scope;
    table.resize(bucket_count);
}

inline scope_table *scope_table::get_parent_scope()
{
    return parent_scope;
}

inline int scope_table::get_unique_id()
{
    return unique_id;
}

inline symbol_info *scope_table::lookup_in_scope(symbol_info* symbol)
{
    if(symbol == NULL)
    {
        return NULL;
    }
    int bucket_index = hash_function(symbol->getname());
    for(symbol_info *entry : table[bucket_index])
    {
        if(entry->getname() == symbol->getname())
        {
            return entry;
        }
    }
    return NULL;
}

inline bool scope_table::insert_in_scope(symbol_info* symbol)
{
    if(symbol == NULL)
    {
        return false;
    }
    int bucket_index = hash_function(symbol->getname());
    for(auto it = table[bucket_index].begin(); it != table[bucket_index].end(); ++it)
    {
        if((*it)->getname() == symbol->getname())
        {
            delete *it;
            *it = symbol;
            return false;
        }
    }
    table[bucket_index].push_back(symbol);
    return true;
}

inline bool scope_table::delete_from_scope(symbol_info* symbol)
{
    if(symbol == NULL)
    {
        return false;
    }
    int bucket_index = hash_function(symbol->getname());
    for(auto it = table[bucket_index].begin(); it != table[bucket_index].end(); ++it)
    {
        if((*it)->getname() == symbol->getname())
        {
            table[bucket_index].erase(it);
            return true;
        }
    }
    return false;
}

void scope_table::print_scope_table(ofstream& outlog)
{
    outlog << "ScopeTable # "+ to_string(unique_id) << endl;

    for(int bucket_index = 0; bucket_index < bucket_count; bucket_index++)
    {
        if(table[bucket_index].empty())
        {
            continue;
        }
        outlog << bucket_index << " --> " << endl;
        for(symbol_info *entry : table[bucket_index])
        {
            outlog << "< " << entry->getname() << " : " << entry->get_type() << " >" << endl;
            if(entry->get_symbol_kind() == "Function Definition")
            {
                outlog << "Function Definition" << endl;
                outlog << "Return Type: " << entry->get_data_type() << endl;
                outlog << "Number of Parameters: " << entry->get_parameter_count() << endl;
                outlog << "Parameter Details: " << entry->get_parameter_details() << endl;
            }
            else if(entry->get_symbol_kind() == "Array")
            {
                outlog << "Array" << endl;
                outlog << "Type: " << entry->get_data_type() << endl;
                outlog << "Size: " << entry->get_array_size() << endl;
            }
            else
            {
                outlog << "Variable" << endl;
                outlog << "Type: " << entry->get_data_type() << endl;
            }
            outlog << endl;
        }
    }
}

inline scope_table::~scope_table()
{
    for(int bucket_index = 0; bucket_index < bucket_count; bucket_index++)
    {
        for(symbol_info *entry : table[bucket_index])
        {
            delete entry;
        }
        table[bucket_index].clear();
    }
}