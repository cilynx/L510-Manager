/* window.vala
 *
 * Copyright 2019 Randy C. Will
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace L510_manager {
	[GtkTemplate (ui = "/com/wolfteck/L510Manager/window.ui")]
	public class Window : Gtk.ApplicationWindow {
        [GtkChild]
        Gtk.TreeView all_parameters_treeview;

        [GtkChild]
        Gtk.TreeView parameter_sets_treeview;

        [GtkChild]
        Gtk.TreeView parameter_set_treeview;

        [GtkChild]
        Gtk.Label parameter_set_label;

		public Window (Gtk.Application app) {
			Object (application: app);

            setup_all_parameters_treeview (all_parameters_treeview);

            setup_parameter_sets_treeview (parameter_sets_treeview);
            var parameter_set_selection = parameter_sets_treeview.get_selection ();
            parameter_set_selection.changed.connect (this.on_perameter_sets_selection_changed);

            setup_parameter_set_treeview (parameter_set_treeview);
		}

        private void on_perameter_sets_selection_changed (Gtk.TreeSelection selection) {
            Gtk.TreeModel model;
            Gtk.TreeIter iter;
            string parameter_set_name;

            if (selection.get_selected (out model, out iter)) {
                model.get (iter, 0, out parameter_set_name);
                parameter_set_label.set_text (parameter_set_name);
                var store = new Gtk.TreeStore (7, typeof (string), typeof (string), typeof (string), typeof (string), typeof (string), typeof (string), typeof (string));
    		    parameter_set_treeview.set_model (store);

    		    debug("Fetch parameter set from JSON");
    		    Json.Parser parser = new Json.Parser ();
                var parameter_sets_stream = resources_open_stream ("/com/wolfteck/L510Manager/json/parameter_sets.json", ResourceLookupFlags.NONE);
    		    parser.load_from_stream (parameter_sets_stream);
    		    var parameter_set = parser.get_root ().get_object ().get_member (parameter_set_name);

    		    debug("Grab array from parameter set");
    		    var parameter_array = parameter_set.get_array ();

    		    debug("Fetch parameters from JSON");
                Json.Parser all_parameters_parser = new Json.Parser ();
                var all_parameters_stream = resources_open_stream ("/com/wolfteck/L510Manager/json/parameters.json", ResourceLookupFlags.NONE);
    		    all_parameters_parser.load_from_stream (all_parameters_stream);
    		    var parameters_root = all_parameters_parser.get_root ().get_object ();

                parameter_array.foreach_element ((array, index, node) => {
    		        string[] coordinates = node.get_string ().split ("-");
    		        var group_number = coordinates[0];
    		        var parameter_number = coordinates[1];
    		        var parameter = parameters_root.get_member (group_number).get_object ().get_member (parameter_number).get_object ();
    		        store.insert_with_values (out iter, null, -1,
                                0, group_number,
                                1, parameter_number,
                                2, parameter.get_string_member ("name"),
                                3, parameter.get_string_member ("default"),
                                6, parameter.get_string_member ("unit"),
                                -1); //HERE
                });
    		    debug("Insert parameters into parameter_set_treeview");
            }
        }

        private void setup_parameter_sets_treeview (Gtk.TreeView view) {
        /* This is not very DRY */
            var store = new Gtk.TreeStore (2, typeof (string), typeof (string));
		    view.set_model (store);

            view.insert_column_with_attributes(-1, "Parameter Set", new Gtk.CellRendererText (), "text", 0, null);
//		    view.insert_column_with_attributes(-1, "Parameters", new Gtk.CellRendererText (), "text", 1, null);

		    Gtk.TreeIter iter;
		    try {
                var stream = resources_open_stream ("/com/wolfteck/L510Manager/json/parameter_sets.json", ResourceLookupFlags.NONE);
                Json.Parser parser = new Json.Parser ();
                parser.load_from_stream (stream);
                var parameter_sets = parser.get_root ().get_object ();
                foreach (string parameter_set_name in parameter_sets.get_members ()) {
                    var parameter_set = parameter_sets.get_member (parameter_set_name);
                    store.insert_with_values (out iter, null, -1,
                        0, parameter_set_name,
                        1, parameter_set.get_array,
                        -1);
                }
		    } catch (GLib.Error e) {
                error ("can't load parameters from resource: %s", e.message);
            }
        }

        private void setup_parameter_set_treeview (Gtk.TreeView view) {
        /* This is not very DRY */
            var profile_cell = new Gtk.CellRendererText ();
		    profile_cell.editable = true;
		    profile_cell.edited.connect ((path, new_text) => {

		    });

            view.insert_column_with_attributes(-1, "Group", new Gtk.CellRendererText (), "text", 0, null);
		    view.insert_column_with_attributes(-1, "Number", new Gtk.CellRendererText (), "text", 1, null);
		    view.insert_column_with_attributes(-1, "Parameter", new Gtk.CellRendererText (), "text", 2, null);
		    view.insert_column_with_attributes(-1, "Default", new Gtk.CellRendererText (), "text", 3, null);
		    view.insert_column_with_attributes(-1, "Profile", profile_cell, "text", 4, null);
		    view.insert_column_with_attributes(-1, "VFD", new Gtk.CellRendererText (), "text", 5, null);
		    view.insert_column_with_attributes(-1, "Unit", new Gtk.CellRendererText (), "text", 6, null);
        }

		private void setup_all_parameters_treeview (Gtk.TreeView view) {
		    var store = new Gtk.TreeStore (7, typeof (string), typeof (string), typeof (string), typeof (string), typeof (string), typeof (string), typeof (string));
		    view.set_model (store);

   		    var profile_cell = new Gtk.CellRendererText ();
		    profile_cell.editable = true;
		    profile_cell.edited.connect ((path, new_text) => {

		    });

            view.insert_column_with_attributes(-1, "Group", new Gtk.CellRendererText (), "text", 0, null);
		    view.insert_column_with_attributes(-1, "Number", new Gtk.CellRendererText (), "text", 1, null);
		    view.insert_column_with_attributes(-1, "Parameter", new Gtk.CellRendererText (), "text", 2, null);
		    view.insert_column_with_attributes(-1, "Default", new Gtk.CellRendererText (), "text", 3, null);
		    view.insert_column_with_attributes(-1, "Profile", profile_cell, "text", 4, null);
		    view.insert_column_with_attributes(-1, "VFD", new Gtk.CellRendererText (), "text", 5, null);
		    view.insert_column_with_attributes(-1, "Unit", new Gtk.CellRendererText (), "text", 6, null);

//            Gtk.TreeIter root;
            Gtk.TreeIter group_iter;
            Gtk.TreeIter parameter_iter;

//            store.append (out root, null);
//            store.set (root, 0, "All Parameters", -1);

            try {
                var stream = resources_open_stream ("/com/wolfteck/L510Manager/json/parameters.json", ResourceLookupFlags.NONE);
                Json.Parser parser = new Json.Parser ();
                parser.load_from_stream (stream);
                var parameters = parser.get_root ().get_object ();
                foreach (string group_number in parameters.get_members ()) {
                    var group = parameters.get_member (group_number).get_object ();
                    store.insert_with_values (out group_iter, null, -1,
                        0, group_number,
                        2, group.get_string_member ("name"),
                        -1);
//                    store.append (out group_iter, null);
//                    store.set (group_iter, 0, group_number, 1, "-XX: " + group.get_string_member ("name"), -1);
                    foreach (string parameter_number in group.get_members ()) {
                        var parameter = group.get_member (parameter_number).get_object ();
                        if (parameter_number != "name") {
                            store.insert_with_values (out parameter_iter, group_iter, -1,
                                0, group_number,
                                1, parameter_number,
                                2, parameter.get_string_member ("name"),
                                3, parameter.get_string_member ("default"),
                                6, parameter.get_string_member ("unit"),
                                -1);
//                            store.append (out parameter_iter, group_iter);
//                            store.set (parameter_iter, 0, group_number + "-" + parameter_number + ": " + parameter.get_string_member ("name"), -1);
                        }
                    }
                }
            } catch (GLib.Error e) {
                error ("can't load parameters from resource: %s", e.message);
            }
//            view.expand_all ();
		}
	}
}
