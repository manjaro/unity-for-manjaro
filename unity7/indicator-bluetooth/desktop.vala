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

class Desktop: Profile
{
  private uint idle_rebuild_id = 0;
  private Settings settings;
  private SimpleActionGroup action_group;

  private Menu device_section;
  private HashTable<uint,SimpleAction> connect_actions;

  protected override void dispose ()
  {
    if (idle_rebuild_id != 0)
      {
        Source.remove (idle_rebuild_id); 
        idle_rebuild_id = 0;
      }

    base.dispose ();
  }

  public Desktop (Bluetooth bluetooth, SimpleActionGroup action_group)
  {
    const string profile_name = "desktop";

    base (bluetooth, profile_name);

    this.action_group = action_group;

    connect_actions = new HashTable<uint,SimpleAction>(direct_hash, direct_equal);

    settings = new Settings ("com.canonical.indicator.bluetooth");

    // build the static actions
    Action[] actions = {};
    actions += root_action;
    actions += create_supported_action (bluetooth);
    actions += create_enabled_action (bluetooth);
    actions += create_discoverable_action (bluetooth);
    actions += create_browse_files_action ();
    actions += create_send_file_action ();
    actions += create_show_settings_action ();
    foreach (var a in actions)
      action_group.add_action (a);

    build_menu ();

    // know when to show the indicator & when to hide it
    settings.changed["visible"].connect (()=> update_visibility());
    bluetooth.notify["supported"].connect (() => update_visibility());
    update_visibility ();

    // when devices change, rebuild our device section
    bluetooth.devices_changed.connect (()=> {
      if (idle_rebuild_id == 0)
        idle_rebuild_id = Idle.add (() => {
          rebuild_device_section ();
          idle_rebuild_id = 0;
          return false;
        });
    });
  }

  void update_visibility ()
  {
    visible = bluetooth.supported && settings.get_boolean("visible");
  }

  ///
  ///  MenuItems
  ///

  MenuItem create_device_connection_menuitem (Device device)
  {
    var id = device.id;
    var action_name = @"desktop-device-$(id)-connected";

    var item = new MenuItem (_("Connection"), @"indicator.$action_name");
    item.set_attribute ("x-canonical-type",
                        "s", "com.canonical.indicator.switch");

    // if this doesn't already have an action, create one
    if (!connect_actions.contains (id))
      {
        debug (@"creating action for $action_name");
        var a = new SimpleAction.stateful (action_name,
                                           null,
                                           new Variant.boolean (device.is_connected));

        a.activate.connect (()
          => a.set_state (new Variant.boolean (!a.get_state().get_boolean())));

        a.notify["state"].connect (()
          => bluetooth.set_device_connected (id, a.get_state().get_boolean()));

        connect_actions.insert (device.id, a);
        action_group.add_action (a);
      }
    else
      {
        debug (@"updating action $(device.id) state to $(device.is_connected)");
        var action = connect_actions.lookup (device.id);
        action.set_state (new Variant.boolean (device.is_connected));
      }

    return item;
  }

  void rebuild_device_section ()
  {
    device_section.remove_all ();

    foreach (var device in bluetooth.get_devices())
      {
        Menu submenu = new Menu ();
        MenuItem item;

        if (device.is_connectable)
          submenu.append_item (create_device_connection_menuitem (device));

        /* There is no working backend that can be used there, disable
           the action until that situation gets sorted out
           see http://launchpad.net/bugs/1562822
           
        if (device.supports_browsing)
          submenu.append (_("Browse files…"),
                          @"indicator.desktop-browse-files::$(device.address)");
        */

        if (device.supports_file_transfer)
          submenu.append (_("Send files…"),
                          @"indicator.desktop-send-file::$(device.address)");

        switch (device.device_type)
          {
            case Device.Type.KEYBOARD:
              submenu.append (_("Keyboard Settings…"),
                              "indicator.desktop-show-settings::keyboard");
              break;

            case Device.Type.MOUSE:
            case Device.Type.TABLET:
              submenu.append (_("Mouse and Touchpad Settings…"),
                              "indicator.desktop-show-settings::mouse");
              break;

            case Device.Type.HEADSET:
            case Device.Type.HEADPHONES:
            case Device.Type.OTHER_AUDIO:
              submenu.append (_("Sound Settings…"),
                              "indicator.desktop-show-settings::sound");
              break;
          }

        // only show the device if it's got actions that we can perform on it
        if (submenu.get_n_items () > 0)
          {
            item = new MenuItem (device.name, null);
            item.set_attribute_value ("icon", device.icon.serialize());
            item.set_submenu (submenu);
            device_section.append_item (item);
          }
      }
  }

  void build_menu ()
  {
    Menu section;
    MenuItem item;

    // quick toggles section
    section = new Menu ();
    section.append_item (create_enabled_menuitem ());
    item = new MenuItem (_("Visible"), "indicator.desktop-discoverable");
    item.set_attribute ("x-canonical-type", "s",
                        "com.canonical.indicator.switch");
    section.append_item (item);
    menu.append_section (null, section);

    // devices section
    device_section = new Menu ();
    rebuild_device_section ();
    menu.append_section (null, device_section);

    // settings section
    section = new Menu ();
    section.append (_("Bluetooth Settings…"),
                    "indicator.desktop-show-settings::bluetooth");
    menu.append_section (null, section);
  }

  ///
  ///  Actions
  ///

  private bool is_desktop (string name)
  {
    var desktop_name_list = Environment.get_variable ("XDG_CURRENT_DESKTOP");
    if (desktop_name_list == null)
        return false;

    foreach (var n in desktop_name_list.split (":"))
      if (n == name)
        return true;

    return false;
  }

  void show_settings (string panel)
  {
    if (is_desktop ("Unity") && Environment.find_program_in_path ("unity-control-center") != null)
      spawn_command_line_async ("unity-control-center " + panel);
    else
      spawn_command_line_async ("gnome-control-center " + panel);
  }

  Action create_discoverable_action (Bluetooth bluetooth)
  {
    var action = new SimpleAction.stateful ("desktop-discoverable",
                                            null,
                                            new Variant.boolean (bluetooth.discoverable));

    action.activate.connect (()
        => action.set_state (new Variant.boolean (!action.get_state().get_boolean())));

    action.notify["state"].connect (()
        => bluetooth.try_set_discoverable (action.get_state().get_boolean()));

    bluetooth.notify["discoverable"].connect (()
        => action.set_state (new Variant.boolean (bluetooth.discoverable)));

    return action;
  }

  Action create_browse_files_action ()
  {
    var action = new SimpleAction ("desktop-browse-files", VariantType.STRING);
    action.activate.connect ((action, address) => {
      var uri = @"obex://[$(address.get_string())]/";
      var file = File.new_for_uri (uri);
      file.mount_enclosing_volume.begin (MountMountFlags.NONE,
                                         null, null, (obj, res) => {
        try {
          AppInfo.launch_default_for_uri (uri, null);
        } catch (Error e) {
          warning (@"unable to launch '$uri': $(e.message)");
        }
      });
    });
    return action;
  }

  Action create_send_file_action ()
  {
    var action = new SimpleAction ("desktop-send-file", VariantType.STRING);

    action.activate.connect ((action, address) => {
      var cmd = @"bluetooth-sendto --device=$(address.get_string())";
      spawn_command_line_async (cmd);
    });

    return action;
  }

  Action create_show_settings_action ()
  {
    var action = new SimpleAction ("desktop-show-settings", VariantType.STRING);

    action.activate.connect ((action, panel)
        => show_settings (panel.get_string()));

    return action;
  }
}
