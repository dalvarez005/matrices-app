// Tema de la landing: claro (por defecto), oscuro o el del sistema.
// Se guarda en la misma clave que usa la app (shared_preferences web), así
// landing y app comparten la elección.
(function () {
  var KEY = "flutter.matrices.theme";
  var media = window.matchMedia("(prefers-color-scheme: dark)");

  function saved() {
    try {
      var v = JSON.parse(localStorage.getItem(KEY));
      return v === "dark" || v === "system" ? v : "light";
    } catch (e) { return "light"; }
  }
  function apply(mode) {
    var dark = mode === "dark" || (mode === "system" && media.matches);
    document.documentElement.setAttribute("data-theme", dark ? "dark" : "light");
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute("content", dark ? "#101018" : "#4F46E5");
  }
  apply(saved());
  media.addEventListener && media.addEventListener("change", function () { apply(saved()); });

  var icons = {
    light: '<path d="M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10ZM2 13h2a1 1 0 0 0 0-2H2a1 1 0 0 0 0 2Zm18 0h2a1 1 0 0 0 0-2h-2a1 1 0 0 0 0 2ZM11 2v2a1 1 0 0 0 2 0V2a1 1 0 0 0-2 0Zm0 18v2a1 1 0 0 0 2 0v-2a1 1 0 0 0-2 0ZM5.99 4.58a1 1 0 0 0-1.41 1.41l1.06 1.06a1 1 0 0 0 1.41-1.41L5.99 4.58Zm12.37 12.37a1 1 0 0 0-1.41 1.41l1.06 1.06a1 1 0 0 0 1.41-1.41l-1.06-1.06Zm1.06-10.96a1 1 0 0 0-1.41-1.41l-1.06 1.06a1 1 0 0 0 1.41 1.41l1.06-1.06ZM7.05 18.36a1 1 0 0 0-1.41-1.41l-1.06 1.06a1 1 0 0 0 1.41 1.41l1.06-1.06Z"/>',
    dark: '<path d="M12.3 22a10 10 0 0 0 9.4-6.6 1 1 0 0 0-1.3-1.2A8 8 0 0 1 9.8 3.6a1 1 0 0 0-1.2-1.3A10 10 0 0 0 12.3 22Z"/>',
    system: '<path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm0 18V4a8 8 0 0 1 0 16Z"/>'
  };
  var labels = { light: "Tema: claro", dark: "Tema: oscuro", system: "Tema: como el sistema" };
  var next = { light: "dark", dark: "system", system: "light" };

  document.addEventListener("DOMContentLoaded", function () {
    var btn = document.getElementById("theme-btn");
    if (!btn) return;
    function render() {
      var mode = saved();
      btn.innerHTML = '<svg viewBox="0 0 24 24" fill="currentColor">' + icons[mode] + "</svg>";
      btn.title = labels[mode] + " (toca para cambiar)";
      btn.setAttribute("aria-label", btn.title);
    }
    render();
    btn.onclick = function () {
      var mode = next[saved()];
      try { localStorage.setItem(KEY, JSON.stringify(mode)); } catch (e) {}
      apply(mode);
      render();
    };
  });
})();
