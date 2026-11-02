#ifndef KINETIC_GTK_WINDOW_COMPAT_H_
#define KINETIC_GTK_WINDOW_COMPAT_H_

#include <gtk/gtk.h>

namespace kinetic {
inline GtkWindow* WindowForWidget(GtkWidget* widget) {
  if (!widget) return nullptr;
#if GTK_MAJOR_VERSION >= 4
  GtkRoot* root = gtk_widget_get_root(widget);
  return root && GTK_IS_WINDOW(root) ? GTK_WINDOW(root) : nullptr;
#else
  GtkWidget* root = gtk_widget_get_toplevel(widget);
  return root && GTK_IS_WINDOW(root) ? GTK_WINDOW(root) : nullptr;
#endif
}

inline bool IsFullscreen(GtkWindow* window) {
  if (!window) return false;
#if GTK_MAJOR_VERSION >= 4
  return gtk_window_is_fullscreen(window);
#else
  GdkWindow* surface = gtk_widget_get_window(GTK_WIDGET(window));
  return surface &&
         (gdk_window_get_state(surface) & GDK_WINDOW_STATE_FULLSCREEN) != 0;
#endif
}
}  // namespace kinetic
#endif
