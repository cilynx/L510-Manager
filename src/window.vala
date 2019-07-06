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
        Gtk.Label all_parameters_label;

		public Window (Gtk.Application app) {
			Object (application: app);

            setup_treeview (all_parameters_treeview);
            add (all_parameters_treeview);

            var selection = all_parameters_treeview.get_selection ();
            selection.changed.connect (this.on_selection_changed);
		}

        private void on_selection_changed (Gtk.TreeSelection selection) {
            Gtk.TreeModel model;
            Gtk.TreeIter iter;
            string parameter;

            if (selection.get_selected (out model, out iter)) {
                model.get (iter, 0, out parameter);
                all_parameters_label.set_text (parameter);
            }
        }

		private void setup_treeview (Gtk.TreeView view) {
		    var store = new Gtk.TreeStore (1, typeof (string));
		    view.set_model (store);

		    view.insert_column_with_attributes(-1, "Parameter", new Gtk.CellRendererText (), "text", 0, null);

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
                    store.append (out group_iter, null);
                    store.set (group_iter, 0, group_number + "-XX: " + group.get_string_member ("name"), -1);
                    foreach (string parameter_number in group.get_members ()) {
                        var parameter = group.get_member (parameter_number).get_object ();
                        if (parameter_number != "name") {
                            store.append (out parameter_iter, group_iter);
                            store.set (parameter_iter, 0, group_number + "-" + parameter_number + ": " + parameter.get_string_member ("name"), -1);
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
