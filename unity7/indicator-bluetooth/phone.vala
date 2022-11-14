/*
 * Copyright 2013 Canonical Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors:
 *   Charles Kerr <charles.kerr@canonical.com>
 */

class Phone: Profile
{
  SimpleActionGroup action_group;

  public Phone (Bluetooth bluetooth, SimpleActionGroup action_group)
  {
    const string profile_name = "phone";
    base (bluetooth, profile_name);

    this.bluetooth = bluetooth;
    this.action_group = action_group;

    // build the static actions
    Action[] actions = {};
    actions += root_action;
    actions += create_supported_action (bluetooth);
    actions += create_enabled_action (bluetooth);
    actions += create_settings_action ();
    foreach (var a in actions)
      action_group.add_action (a);

    var section = new Menu ();
    section.append_item (create_enabled_menuitem ());
    section.append (_("Bluetooth settings…"),
                    "indicator.phone-show-settings::bluetooth");
    menu.append_section (null, section);

    // know when to show the indicator & when to hide it
    bluetooth.notify.connect (() => update_visibility());
    update_visibility ();

    bluetooth.notify.connect (() => update_root_action_state());
  }

  void update_visibility ()
  {
    visible = bluetooth.enabled;
  }

  ///
  ///  Actions
  ///

  void show_settings (string panel)
  {
  }

  Action create_settings_action ()
  {
    var action = new SimpleAction ("phone-show-settings", VariantType.STRING);

    action.activate.connect ((action, panel)
        => show_settings (panel.get_string()));

    return action;
  }
}
