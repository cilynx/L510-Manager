public class VFD_Config : GLib.Object {
    private Group[] groups;
    private Group[] parameter_sets;

    public Group[] get_groups () {
        return groups;
    }

    public Group[] get_parameter_sets () {
        return parameter_sets;
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

public class Parameter : GLib.Object {
    public Group group;
    public string dflt;
    public string name;
    public string number;
    public string unit;

    public int integer {
        get { return int.parse (number); }
    }

    public double scale {
        get {
            if (this.dflt != null && this.dflt.contains(".")) {
                return (this.dflt.length - this.dflt.index_of_char ('.') == 2) ? 0.1 : 0.01;
            } else {
                return 1;
            }
        }
    }

    public string format {
        get {
            return (this.scale == 0.1) ? "%.1f" : "%.2f";
        }
    }

    public Parameter (Group parameter_group, string parameter_number, string parameter_name) {
        number = parameter_number;
        name = parameter_name;
        group = parameter_group;
        group.add_parameter(this);
    }

}
