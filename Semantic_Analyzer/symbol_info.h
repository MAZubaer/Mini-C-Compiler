#include<bits/stdc++.h>
using namespace std;

class symbol_info
{
private:
    string name;
    string type;
    string symbol_kind;
    string data_type;
    int array_size;
    vector<pair<string, string>> parameters;
    vector<string> arg_types;

public:
    symbol_info(string name = "", string type = "")
    {
        this->name = name;
        this->type = type;
        this->symbol_kind = "";
        this->data_type = "";
        this->array_size = -1;
    }
    string getname()
    {
        return name;
    }
    string get_type()
    {
        return type;
    }
    void set_name(string name)
    {
        this->name = name;
    }
    void set_type(string type)
    {
        this->type = type;
    }
    void set_symbol_kind(string symbol_kind)
    {
        this->symbol_kind = symbol_kind;
    }
    string get_symbol_kind()
    {
        return symbol_kind;
    }
    void set_data_type(string data_type)
    {
        this->data_type = data_type;
    }
    string get_data_type()
    {
        return data_type;
    }
    void set_array_size(int array_size)
    {
        this->array_size = array_size;
    }
    int get_array_size()
    {
        return array_size;
    }
    void add_parameter(string parameter_type, string parameter_name = "")
    {
        parameters.push_back({parameter_type, parameter_name});
    }
    vector<pair<string, string>> get_parameters()
    {
        return parameters;
    }
    int get_parameter_count()
    {
        return (int)parameters.size();
    }
    string get_parameter_details()
    {
        string result;
        for(size_t index = 0; index < parameters.size(); index++)
        {
            if(index)
            {
                result += ", ";
            }
            result += parameters[index].first;
            if(!parameters[index].second.empty())
            {
                result += " ";
                result += parameters[index].second;
            }
        }
        return result;
    }

    void add_arg_type(const string &t)
    {
        arg_types.push_back(t);
    }
    vector<string> get_arg_types()
    {
        return arg_types;
    }
    int get_arg_count()
    {
        return (int)arg_types.size();
    }

    ~symbol_info()
    {
    }
};