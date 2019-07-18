public class VFD_Config : GLib.Object {
    private Group[] groups;

    public Group[] get_groups () {
        return groups;
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

    public Group (VFD_Config config, string group_number, string group_name) {
        name = group_name;
        number = group_number;
    }

    public void add_parameter (Parameter parameter) {
        parameters += parameter;
    }

    public void new_parameter (string number, string name) {
        parameters += new Parameter (this, number, name);
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

    public Parameter (Group group, string parameter_number, string parameter_name) {
        number = parameter_number;
        name = parameter_name;
        group.add_parameter(this);
    }

}
