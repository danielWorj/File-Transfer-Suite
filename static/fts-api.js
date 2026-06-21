/* ==========================================================================
   FTS — File Transfer Suite — client API partagé
   --------------------------------------------------------------------------
   Centralise tous les appels au backend Flask (api/transfertapi.py) :
   - récupération / mémorisation du token de pairing
   - requêtes REST authentifiées (fetch)
   - upload avec suivi de progression (XHR)
   - connexion temps réel via Socket.IO (Flask-SocketIO, namespace /api/ws)
   - petite couche d'UI partagée : toasts, formatage de taille/date

   IMPORTANT : le temps réel repose désormais sur Socket.IO (et non plus sur
   les WebSockets natifs comme avec FastAPI). La bibliothèque client Socket.IO
   doit être chargée AVANT ce fichier, en local (pas de CDN, pour fonctionner
   sans internet), par ex. :
     <script src="./vendor/socketio/socket.io.min.js"></script>

   En Angular, ce fichier deviendrait un service injectable (FtsApiService)
   basé sur HttpClient + le client socket.io-client.
   ========================================================================== */

(function (window) {
  "use strict";

  // Le frontend est servi par le même serveur Flask (cf. main.py), donc on
  // appelle l'API en relatif : pas besoin de coder une IP/port en dur.
  var ORIGIN = window.location.origin;
  var TOKEN_STORAGE_KEY = "fts_pairing_token";

  // Namespace Socket.IO côté serveur (doit correspondre à transfertapi.py).
  var WS_NAMESPACE = "/api/ws";

  // ---------------------------------------------------------------------
  // Gestion du token de pairing
  // ---------------------------------------------------------------------

  function getToken() {
    return window.sessionStorage.getItem(TOKEN_STORAGE_KEY) || readTokenFromUrl();
  }

  function setToken(token) {
    if (token) {
      window.sessionStorage.setItem(TOKEN_STORAGE_KEY, token);
    }
  }

  /**
   * Oublie le token courant côté client. Utilisé quand le serveur signale
   * que le token a été invalidé (ex : coupure WiFi détectée côté PC, voir
   * l'événement temps réel "session:expired"), pour forcer un nouvel
   * appairage plutôt que de continuer à utiliser un token périmé.
   */
  function clearToken() {
    window.sessionStorage.removeItem(TOKEN_STORAGE_KEY);
  }

  function readTokenFromUrl() {
    var params = new URLSearchParams(window.location.search);
    var fromUrl = params.get("token");
    if (fromUrl) {
      setToken(fromUrl);
      return fromUrl;
    }
    return null;
  }

  /**
   * Récupère le token courant, en le demandant au serveur via /api/session
   * si aucun n'est encore connu côté client (cas de l'interface PC qui
   * tourne sur la même machine que le serveur : pas besoin de scan QR).
   */
  function ensureToken() {
    var existing = getToken();
    if (existing) return Promise.resolve(existing);
    return fetch(ORIGIN + "/api/session")
      .then(function (res) {
        if (!res.ok) throw new Error("Aucune session active");
        return res.json();
      })
      .then(function (data) {
        setToken(data.token);
        return data.token;
      });
  }

  // ---------------------------------------------------------------------
  // Requêtes REST
  // ---------------------------------------------------------------------

  function authHeaders(extra) {
    var headers = Object.assign({}, extra || {});
    var token = getToken();
    if (token) headers["Authorization"] = "Bearer " + token;
    return headers;
  }

 function request(path, options) {
    options = options || {};
    return ensureToken()
      .catch(function () {
        return null; // tant pis, la requête partira sans token et le serveur renverra 401
      })
      .then(function () {
        var opts = {
          method: options.method || "GET",
          headers: authHeaders(options.headers),
          body: options.body,
        };
        return fetch(ORIGIN + path, opts).then(function (res) {
          
          // ----- Suppression du token si expiré -----
          if (res.status === 401) {
            clearToken();
          }
          // -------------------------------------------

          if (!res.ok) {
            return res
              .json()
              .catch(function () {
                return { detail: res.statusText };
              })
              .then(function (err) {
                throw new Error(err.detail || "Erreur réseau (" + res.status + ")");
              });
          }
          var contentType = res.headers.get("content-type") || "";
          if (contentType.indexOf("application/json") !== -1) return res.json();
          return res;
        });
      });
  }

  /** Vérifie que le serveur répond. */
  function ping() {
    return fetch(ORIGIN + "/api/ping").then(function (res) {
      return res.ok;
    });
  }

  /** Valide/confirme l'appairage avec le token courant (ou fourni). */
  function pair(token) {
    var resolveToken = token ? Promise.resolve(token) : ensureToken();
    return resolveToken.then(function (t) {
      return request("/api/pair", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ token: t }),
      }).then(function (res) {
        setToken(t);
        return res;
      });
    });
  }

  /** Récupère la liste des fichiers de la session courante. */
  function listFiles() {
    return request("/api/files");
  }

  /** Télécharge un fichier (token en en-tête Authorization -> on fetch en blob). */
  /** Télécharge un fichier depuis le serveur avec suivi de progression */
  function downloadFile(fileId, filename, onProgress) {
    return ensureToken()
      .catch(function () {
        return null; // continue même sans token (le serveur gérera la sécurité)
      })
      .then(function () {
        return new Promise(function (resolve, reject) {
          var xhr = new XMLHttpRequest();
          xhr.open("GET", ORIGIN + "/api/download/" + fileId);

          // Injection des en-têtes d'authentification requis
          var headers = authHeaders();
          for (var key in headers) {
            if (headers.hasOwnProperty(key)) {
              xhr.setRequestHeader(key, headers[key]);
            }
          }

          xhr.responseType = "blob";

          // Gestion du suivi de progression du téléchargement
          if (typeof onProgress === "function") {
            xhr.addEventListener("progress", function (e) {
              if (e.lengthComputable) {
                var percent = Math.round((e.loaded / e.total) * 100);
                onProgress(percent);
              }
            });
          }

          xhr.onload = function () {
            if (xhr.status >= 200 && xhr.status < 300) {
              var blob = xhr.response;
              var url = window.URL.createObjectURL(blob);
              var a = document.createElement("a");
              a.href = url;
              a.download = filename || "fichier";
              document.body.appendChild(a);
              a.click();
              a.remove();
              window.URL.revokeObjectURL(url);
              resolve();
            } else {
              reject(new Error("Téléchargement impossible (" + xhr.status + ")"));
            }
          };

          xhr.onerror = function () {
            reject(new Error("Erreur réseau lors du téléchargement."));
          };

          xhr.send();
        });
      });
  }

  /** Supprime un fichier de la session. */
  function deleteFile(fileId) {
    return request("/api/files/" + fileId, { method: "DELETE" });
  }

  /**
   * Envoie un fichier avec suivi de progression.
   * onProgress(percent) est appelé régulièrement pendant l'upload.
   * Retourne une Promise résolue avec les métadonnées du fichier créé.
   *
   * NB : `direction` est envoyé comme champ du formulaire multipart (et non
   * plus en query string), car le backend Flask le lit via request.form.
   */
  function uploadFile(file, direction, onProgress) {
    return ensureToken().then(function (token) {
      return new Promise(function (resolve, reject) {
        var xhr = new XMLHttpRequest();
        var formData = new FormData();
        formData.append("file", file);
        formData.append("direction", direction || "pc-to-mobile");

        xhr.open("POST", ORIGIN + "/api/upload", true);
        xhr.setRequestHeader("Authorization", "Bearer " + token);

        xhr.upload.onprogress = function (evt) {
          if (evt.lengthComputable && onProgress) {
            onProgress(Math.round((evt.loaded / evt.total) * 100));
          }
        };

        xhr.onload = function () {
          if (xhr.status >= 200 && xhr.status < 300) {
            try {
              resolve(JSON.parse(xhr.responseText));
            } catch (e) {
              resolve({});
            }
          } else {
            var message = "Échec de l'envoi (" + xhr.status + ")";
            try {
              message = JSON.parse(xhr.responseText).detail || message;
            } catch (e) {}
            reject(new Error(message));
          }
        };

        xhr.onerror = function () {
          reject(new Error("Erreur réseau pendant l'envoi"));
        };

        xhr.send(formData);
      });
    });
  }

  // ---------------------------------------------------------------------
  // Temps réel via Socket.IO
  // ---------------------------------------------------------------------

  /**
   * Ouvre un canal Socket.IO et reconnecte automatiquement en cas de coupure
   * (la reconnexion est gérée nativement par Socket.IO).
   * handlers: { onOpen, onClose, onEvent(eventName, data) }
   * Retourne un objet avec .close() pour fermer proprement.
   */
  function connectRealtime(handlers) {
    handlers = handlers || {};

    if (typeof window.io === "undefined") {
      // La bibliothèque client Socket.IO n'a pas été chargée : on prévient
      // explicitement plutôt que d'échouer en silence.
      console.error(
        "[FTS] Client Socket.IO introuvable. Ajoutez " +
          '<script src="./vendor/socketio/socket.io.min.js"></script> ' +
          "avant fts-api.js."
      );
      return { close: function () {} };
    }

    var socket = null;
    var closedByUser = false;
    var retryDelay = 1500;

    function open() {
      if (closedByUser) return;
      ensureToken()
        .then(function (token) {
          // Connexion sur le namespace "/api/ws". Le token de pairing est
          // transmis via le canal d'authentification Socket.IO (lu côté
          // serveur dans le handler connect(auth)), et non plus en query
          // string comme avec les WebSockets natifs de FastAPI.
          socket = window.io(ORIGIN + WS_NAMESPACE, {
            auth: { token: token },
            transports: ["websocket", "polling"],
            reconnection: true,
            reconnectionDelay: retryDelay,
          });

          socket.on("connect", function () {
            if (handlers.onOpen) handlers.onOpen();
          });

          socket.on("disconnect", function () {
            if (handlers.onClose) handlers.onClose();
          });

          socket.on("connect_error", function () {
            // Auth refusée ou serveur indisponible : Socket.IO retentera seul
            // tant que reconnection reste activée.
            if (handlers.onClose) handlers.onClose();
          });

          // Le serveur diffuse des événements nommés ("files:updated",
          // "transfer:complete", "connected"). Le payload des diffusions est
          // enveloppé sous la forme { event, data } : on le déballe ici pour
          // conserver l'API onEvent(eventName, data) attendue par les pages.
          socket.onAny(function (eventName, payload) {
            if (!handlers.onEvent) return;
            var data =
              payload && typeof payload === "object" && "data" in payload
                ? payload.data
                : payload;
            handlers.onEvent(eventName, data);
          });
        })
        .catch(function () {
          // Pas encore de session active côté serveur : on retente plus tard.
          if (!closedByUser) setTimeout(open, retryDelay);
        });
    }

    open();

    return {
      close: function () {
        closedByUser = true;
        if (socket) socket.close();
      },
    };
  }

  // ---------------------------------------------------------------------
  // Utilitaires d'affichage
  // ---------------------------------------------------------------------

  function formatSize(bytes) {
    if (bytes === 0 || bytes === undefined || bytes === null) return "0 o";
    var units = ["o", "Ko", "Mo", "Go"];
    var i = 0;
    var value = bytes;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    var formatted = i === 0 ? String(value) : value.toFixed(1).replace(".", ",");
    return formatted + " " + units[i];
  }

  function formatDate(isoString) {
    try {
      var d = new Date(isoString);
      var pad = function (n) {
        return String(n).padStart(2, "0");
      };
      return (
        pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear() +
        " " + pad(d.getHours()) + ":" + pad(d.getMinutes())
      );
    } catch (e) {
      return isoString || "";
    }
  }

  function iconForFile(name) {
    var ext = (name.split(".").pop() || "").toLowerCase();
    var map = {
      pdf: "fa-file-pdf",
      zip: "fa-file-zipper",
      rar: "fa-file-zipper",
      "7z": "fa-file-zipper",
      mp4: "fa-file-video",
      mov: "fa-file-video",
      avi: "fa-file-video",
      mp3: "fa-file-audio",
      wav: "fa-file-audio",
      jpg: "fa-file-image",
      jpeg: "fa-file-image",
      png: "fa-file-image",
      gif: "fa-file-image",
      webp: "fa-file-image",
      doc: "fa-file-word",
      docx: "fa-file-word",
      xls: "fa-file-excel",
      xlsx: "fa-file-excel",
      ppt: "fa-file-powerpoint",
      pptx: "fa-file-powerpoint",
      txt: "fa-file-lines",
    };
    return map[ext] || "fa-file";
  }

  // ---------------------------------------------------------------------
  // Toasts (notifications discrètes)
  // ---------------------------------------------------------------------

  function ensureToastStack() {
    var stack = document.querySelector(".fts-toast-stack");
    if (!stack) {
      stack = document.createElement("div");
      stack.className = "fts-toast-stack";
      document.body.appendChild(stack);
    }
    return stack;
  }

  function toast(message, type) {
    var stack = ensureToastStack();
    var el = document.createElement("div");
    el.className = "fts-toast" + (type ? " is-" + type : "");
    var iconClass =
      type === "error" ? "fa-circle-exclamation" : type === "success" ? "fa-circle-check" : "fa-circle-info";
    el.innerHTML = '<i class="fa-solid ' + iconClass + '"></i><span></span>';
    el.querySelector("span").textContent = message;
    stack.appendChild(el);
    setTimeout(function () {
      el.style.transition = "opacity .25s ease";
      el.style.opacity = "0";
      setTimeout(function () {
        el.remove();
      }, 250);
    }, 3600);
  }

  // ---------------------------------------------------------------------
  // Export global
  // ---------------------------------------------------------------------

  window.FtsApi = {
    getToken: getToken,
    setToken: setToken,
    clearToken: clearToken,
    ensureToken: ensureToken,
    ping: ping,
    pair: pair,
    listFiles: listFiles,
    downloadFile: downloadFile,
    deleteFile: deleteFile,
    uploadFile: uploadFile,
    connectRealtime: connectRealtime,
    formatSize: formatSize,
    formatDate: formatDate,
    iconForFile: iconForFile,
    toast: toast,
  };
})(window);