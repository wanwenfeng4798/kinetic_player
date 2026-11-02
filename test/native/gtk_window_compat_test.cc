#include "gtk_window_compat.h"
#include <chrono>
#include <thread>
#include <iostream>

void pump() {
  for (int i = 0; i < 60; ++i) {
    while (g_main_context_iteration(nullptr, false)) {}
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
}

int main() {
#if GTK_MAJOR_VERSION >= 4
  gtk_init();
  GtkWidget* window = gtk_window_new();
#else
  gtk_init(nullptr, nullptr);
  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
#endif
  GtkWidget* child = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
  gtk_window_set_default_size(GTK_WINDOW(window), 480, 320);
#if GTK_MAJOR_VERSION >= 4
  gtk_window_set_child(GTK_WINDOW(window), child);
  gtk_window_present(GTK_WINDOW(window));
#else
  gtk_container_add(GTK_CONTAINER(window), child);
  gtk_widget_show_all(window);
#endif
  pump();
  if (kinetic::WindowForWidget(child) != GTK_WINDOW(window)) return 1;
  if (kinetic::WindowForWidget(nullptr) || kinetic::IsFullscreen(nullptr)) return 2;
  gtk_window_fullscreen(GTK_WINDOW(window));
  pump();
#if GTK_MAJOR_VERSION >= 4
  auto* surface = gtk_native_get_surface(GTK_NATIVE(window));
  std::cout << "GTK4 mapped=" << gtk_widget_get_mapped(window)
            << " state=" << (surface ? gdk_toplevel_get_state(GDK_TOPLEVEL(surface)) : 0)
            << " fullscreen=" << kinetic::IsFullscreen(GTK_WINDOW(window)) << std::endl;
#endif
  if (!kinetic::IsFullscreen(GTK_WINDOW(window))) return 3;
  gtk_window_fullscreen(GTK_WINDOW(window));
  pump();
  if (!kinetic::IsFullscreen(GTK_WINDOW(window))) return 4;
  gtk_window_unfullscreen(GTK_WINDOW(window));
  pump();
  if (kinetic::IsFullscreen(GTK_WINDOW(window))) return 5;
#if GTK_MAJOR_VERSION >= 4
  gtk_window_destroy(GTK_WINDOW(window));
#else
  gtk_widget_destroy(window);
#endif
  std::cout << "PASS GTK " << GTK_MAJOR_VERSION
            << " root, enter, idempotent enter, exit, null window" << std::endl;
}
