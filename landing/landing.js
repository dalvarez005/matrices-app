// Landing: detecta el dispositivo, destaca su opción de instalación y carga
// los datos del APK publicado.
(function () {
  var local = location.hostname === "localhost" || location.hostname === "127.0.0.1";
  var API = local ? "http://localhost:5120" : "https://matricalcapi.quantis.site";

  var ua = navigator.userAgent;
  var isIOS = /iPhone|iPad|iPod/.test(ua) ||
    (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  var isAndroid = /Android/i.test(ua);
  var device = isIOS ? "ios" : isAndroid ? "android" : "pc";
  function isIPad() {
    return /iPad/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  }

  var dialog = document.getElementById("ios-dialog");
  function showIOS(e) {
    if (e) e.preventDefault();
    if (dialog.showModal) dialog.showModal();
    else location.hash = "instalar";
  }
  document.getElementById("ios-close").onclick = function () { dialog.close(); };

  // Botones principales según el dispositivo.
  var cta = document.getElementById("cta");
  var hint = document.getElementById("cta-hint");
  function button(text, href, primary, onClick) {
    var a = document.createElement("a");
    a.className = "btn " + (primary ? "btn-primary" : "btn-ghost");
    a.textContent = text;
    a.href = href;
    if (onClick) a.onclick = onClick;
    cta.appendChild(a);
    return a;
  }
  var heroApk = null;
  if (device === "ios") {
    button("Instalar en iPhone", "#instalar", true, showIOS);
    button("Usar en el navegador", "app/", false);
    hint.textContent = "Se instala desde Safari en 3 pasos, sin App Store.";
  } else if (device === "android") {
    heroApk = button("Descargar para Android", "#instalar", true);
    button("Usar en el navegador", "app/", false);
    hint.textContent = "Archivo APK directo, sin Play Store.";
  } else {
    button("Abrir la app", "app/", true);
    button("Instalar en el teléfono", "#instalar", false);
    hint.textContent = "Gratis. Funciona en cualquier navegador moderno.";
  }

  // Destaca la opción de este dispositivo y la pone primero.
  var names = { ios: isIPad() ? "iPad" : "iPhone", android: "Android", pc: "computadora" };
  var options = document.querySelectorAll(".option");
  for (var i = 0; i < options.length; i++) {
    var opt = options[i];
    if (opt.getAttribute("data-device") === device) {
      opt.classList.add("highlight");
      var tag = opt.querySelector(".tag");
      tag.textContent = "Recomendado para tu " + names[device];
      tag.hidden = false;
      opt.parentNode.insertBefore(opt, opt.parentNode.firstChild);
    }
  }

  // Datos del APK.
  var apkBtn = document.getElementById("apk-btn");
  var apkMeta = document.getElementById("apk-meta");
  function mb(bytes) { return (bytes / 1048576).toFixed(1).replace(".", ",") + " MB"; }
  function date(iso) {
    try { return new Date(iso).toLocaleDateString("es", { day: "numeric", month: "long", year: "numeric" }); }
    catch (e) { return ""; }
  }
  fetch(API + "/api/apk")
    .then(function (r) { return r.json(); })
    .then(function (info) {
      if (!info.available) {
        apkMeta.textContent = "La versión para Android estará disponible muy pronto.";
        if (heroApk) heroApk.setAttribute("aria-disabled", "true");
        return;
      }
      var url = API + "/api/apk/download";
      apkBtn.href = url;
      apkBtn.removeAttribute("aria-disabled");
      if (heroApk) heroApk.href = url;
      apkMeta.textContent = "Versión " + info.version + " · " + mb(info.sizeBytes) +
        " · " + date(info.uploadedAt) + (info.notes ? " — " + info.notes : "");
    })
    .catch(function () {
      apkMeta.textContent = "No se pudo consultar la versión. Intenta de nuevo en un momento.";
    });
})();
