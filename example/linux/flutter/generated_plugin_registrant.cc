//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <kinetic_player/kinetic_player_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) kinetic_player_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "KineticPlayerPlugin");
  kinetic_player_plugin_register_with_registrar(kinetic_player_registrar);
}
