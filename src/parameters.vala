public class VFD_Config : GLib.Object {
    private Group[] groups;
    private Group[] parameter_sets;

    public Group[] get_groups () {
        return groups;
    }

    public Group[] get_parameter_sets () {
        return parameter_sets;
    }

    public int group_count {
        get { return groups.length; }
    }

    public int parameter_count {
        get {
            int sum = 0;
            foreach (Group group in groups) { sum += group.parameter_count; }
            return sum;
        }
    }

    public Group get_parameter_set (string search) {
        foreach (Group parameter_set in parameter_sets) {
            print("Name: %s\n", parameter_set.name);
            print("Number: %s\n", parameter_set.number);
            if (parameter_set.number == search || parameter_set.name == search) {
                return parameter_set;
            }
        }
        error ("No match found: %s", search);
    }

    public Group get_group (string search) {
        foreach (Group group in groups) {
            print("Name: %s\n", group.name);
            print("Number: %s\n", group.number);
            if (group.number == search || group.name == search) {
                return group;
            }
        }
        error ("No match found: %s", search);
    }

    public Parameter get_parameter (string search) {
        foreach (Group group in groups) {
            foreach (Parameter parameter in group.get_parameters ()) {
                if (parameter.name == search || group.number + "-" + parameter.number == search) {
                    return parameter;
                }
            }
        }
        error ("No match found");
    }

    public void load_parameter_sets (string resource) {
        try {
            var stream = resources_open_stream (resource, ResourceLookupFlags.NONE);
            Json.Parser parser = new Json.Parser ();
            parser.load_from_stream (stream);
            var root_object = parser.get_root ().get_object ();
            foreach (string parameter_set_name in root_object.get_members ()) {
                var json_parameter_set = root_object.get_member (parameter_set_name);
                var parameter_set = new Group (this, null, parameter_set_name);
                parameter_sets += parameter_set;
                var parameter_array = json_parameter_set.get_array ();
                parameter_array.foreach_element ((array, index, node) => {
                    var parameter = this.get_parameter (node.get_string ());
                    parameter_set.add_parameter (parameter);
                });
            }
        } catch (GLib.Error e) {
            error ("can't load parameter sets from resource: %s", e.message);
        }
    }

    public VFD_Config (string resource) {
        try {
            var stream = resources_open_stream (resource, ResourceLookupFlags.NONE);
            Json.Parser parser = new Json.Parser ();
            parser.load_from_stream (stream);
            var root_object = parser.get_root ().get_object ();
            foreach (string group_number in root_object.get_members ()) {
                var json_group = root_object.get_member (group_number).get_object ();
                var group = new Group (this, group_number, json_group.get_string_member ("name"));
                groups += group;
                foreach (string parameter_number in json_group.get_members ()) {
                    if (parameter_number != "name") {
                        var json_parameter = json_group.get_member (parameter_number).get_object ();
                        var parameter = new Parameter(group, parameter_number, json_parameter.get_string_member ("name"));
                        if (json_parameter.has_member ("unit")) {
                        parameter.unit = json_parameter.get_string_member ("unit");
                        }
                        if (json_parameter.has_member ("default")) {
                            parameter.dflt = json_parameter.get_string_member ("default");
                        }
                        if (json_parameter.has_member ("options")) {
                            var options = json_parameter.get_member ("options").get_object ();
                            foreach (string id in options.get_members ()) {
                                parameter.add_option(id, options.get_string_member (id));
                            }
                        }
                    }
                }
            }
        } catch (GLib.Error e) {
            error ("can't load parameters from resource: %s", e.message);
        }
    }
}

public class Group : GLib.Object {
    private Parameter[] parameters;

    public VFD_Config vfd_config;
    public string name;
    public string number;

    public int integer {
        get { return int.parse (number); }
    }

    public int parameter_count {
        get { return parameters.length; }
    }

    public Group (VFD_Config config, string? group_number, string group_name) {
        name = group_name;
        number = group_number;
    }

    public void add_parameter (Parameter parameter) {
        parameters += parameter;
    }

    public void new_parameter (string number, string name) {
        new Parameter (this, number, name);
    }

    public Parameter[] get_parameters () {
        return parameters;
    }

}

public class Option : GLib.Object {
    public string id;
    public string name;

    public Option (string option_id, string option_name) {
        id = option_id;
        name = option_name;
    }
}

public class Parameter : GLib.Object {
    private Option[] options;
    private string _dflt;

    public Group group;
    public string name;
    public string number;
    public string unit;

    public string dflt {
        get {
            print("Getting dflt.  _dflt is:%s\n", _dflt);
            if (this.has_options) {
                return this.option(_dflt).name;
            } else {
                return _dflt;
            }
        }
        set { _dflt = value; }
    }

    public Option option (string search) {
        print("Parameter.option: Looking for %s\n", search);
        foreach (Option option in options) {
            print("id:%s\n", option.id);
            print("name:%s\n", option.name);

            if (option.id == search || option.name == search) {
                return option;
            }
        }
        error ("Parameter.option: No match found");
    }

    public int integer {
        get { return int.parse (number); }
    }

    public double scale {
        get {
            if (this._dflt != null && this._dflt.contains(".")) {
                return (this._dflt.length - this._dflt.index_of_char ('.') == 2) ? 0.1 : 0.01;
            } else {
                return 1;
            }
        }
    }

    public string format {
        get { return (this.scale == 0.1) ? "%.1f" : "%.2f"; }
    }

    public bool has_options {
        get { return this.options.length > 0; }
    }

    public void add_option (string id, string name) {
        var option = new Option (id, name);
        options += option;
        print("%s\n", option.name);
    }

    public Parameter (Group parameter_group, string parameter_number, string parameter_name) {
        number = parameter_number;
        name = parameter_name;
        group = parameter_group;
        group.add_parameter(this);
    }

}
