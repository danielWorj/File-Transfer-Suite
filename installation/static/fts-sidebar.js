/* ==========================================================================
   FTS — barre de navigation latérale partagée
   --------------------------------------------------------------------------
   Injecte le markup de la sidebar dans n'importe quelle page disposant
   d'un conteneur <div id="fts-sidebar-mount"></div>, et marque l'item actif
   selon data-fts-page porté par .fts-app.
   ========================================================================== */

(function (window, document) {
  "use strict";

  var LINKS = [
    { page: "envoi", href: "./envoi.html", icon: "fa-paper-plane", label: "Envoyer" },
    { page: "reception", href: "./reception.html", icon: "fa-inbox", label: "Recevoir" },
    { page: "historique", href: "./historique.html", icon: "fa-clock-rotate-left", label: "Historique" },
  ];

  function buildSidebar(activePage) {
    var nav = LINKS.map(function (link) {
      var activeClass = link.page === activePage ? " is-active" : "";
      return (
        '<a class="fts-sidebar-link' + activeClass + '" href="' + link.href + '">' +
        '<i class="fa-solid ' + link.icon + '"></i><span>' + link.label + "</span>" +
        "</a>"
      );
    }).join("");

    return (
      '<aside class="fts-sidebar">' +
      '<div class="fts-sidebar-brand">' +
      '<span class="fts-sidebar-brand-mark"><i class="fa-solid fa-share-nodes"></i></span>' +
      '<span class="fts-sidebar-brand-text">FTS<small>File Transfer Suite</small></span>' +
      "</div>" +
      '<nav class="fts-sidebar-nav">' + nav + "</nav>" +
      '<div class="fts-sidebar-foot">' +
      '<div class="fts-sidebar-conn" id="fts-sidebar-conn">' +
      '<span class="fts-status-dot is-waiting is-pulse"></span>' +
      '<span id="fts-sidebar-conn-text">Connexion…</span>' +
      "</div>" +
      "</div>" +
      "</aside>"
    );
  }

  function init() {
    var appRoot = document.querySelector(".fts-app");
    var mount = document.getElementById("fts-sidebar-mount");
    if (!appRoot || !mount) return;

    var activePage = appRoot.getAttribute("data-fts-page");
    mount.outerHTML = buildSidebar(activePage);

    // Statut serveur dans le pied de sidebar : vrai ping API.
    var dot = document.querySelector("#fts-sidebar-conn .fts-status-dot");
    var text = document.getElementById("fts-sidebar-conn-text");

    function setStatus(state) {
      if (!dot || !text) return;
      dot.classList.remove("is-online", "is-offline", "is-waiting", "is-pulse");
      if (state === "online") {
        dot.classList.add("is-online");
        text.textContent = "Serveur connecté";
      } else if (state === "offline") {
        dot.classList.add("is-offline");
        text.textContent = "Serveur injoignable";
      } else {
        dot.classList.add("is-waiting", "is-pulse");
        text.textContent = "Connexion…";
      }
    }

    function checkServer() {
      if (!window.FtsApi) return;
      window.FtsApi.ping()
        .then(function (ok) {
          setStatus(ok ? "online" : "offline");
        })
        .catch(function () {
          setStatus("offline");
        });
    }

    checkServer();
    setInterval(checkServer, 8000);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})(window, document);