"use strict";
(() => {
  const article = document.querySelector('iframe[name="article"]');
  const navigation = document.querySelector('iframe[name="navigation"]');
  // Browsers can restore the old first iframe's article after the viewer layout
  // changes. Reassert the navigation document rather than retaining that history.
  navigation.src = "navigation/index.html";
  const paths = new Set(["about/not-found.html", "about/contents.html"]);
  const collect = items => { for (const item of items || []) { if(item.path) paths.add(item.path); collect(item.children); } };
  collect(window.UBE_DOCS?.sections);
  function safeRoute(value) {
    const [path, anchor, extra] = value.split("#");
    if (!paths.has(path) || extra !== undefined || (anchor && !/^[A-Za-z][\w:.-]*$/.test(anchor))) return "about/not-found.html";
    return path + (anchor ? "#" + anchor : "");
  }
  function requestedRoute() {
    let hash;
    try { hash = decodeURIComponent(window.location.hash.slice(1)); }
    catch { return "about/not-found.html"; }
    return hash ? safeRoute(hash) : "about/contents.html";
  }
  const initial = requestedRoute();
  let awaitingInitial = true;
  let current = initial;
  function highlight() {
    navigation.contentWindow.postMessage({ type: "ube-docs:selection", path: current.split("#")[0] }, "*");
  }
  function loadRoute() {
    current = requestedRoute();
    article.contentWindow.postMessage({ type: "ube-docs:load", path: current }, "*");
    highlight();
  }
  navigation.addEventListener("load", highlight);
  window.addEventListener("hashchange", loadRoute);
  window.addEventListener("message", event => {
    const data = event.data;
    if (!data || (event.source !== article.contentWindow && event.source !== navigation.contentWindow)) return;
    if (data.type === "ube-docs:navigate" && typeof data.path === "string") {
      const route = safeRoute(data.path);
      if (requestedRoute() === route) {
        current = route;
        article.contentWindow.postMessage({ type: "ube-docs:load", path: route }, "*");
      } else window.location.hash = route;
    } else if (data.type === "ube-docs:page" && event.source === article.contentWindow && typeof data.path === "string") {
      const reported = safeRoute(data.path);
      if (awaitingInitial && reported !== initial) return;
      awaitingInitial = false;
      current = reported;
      if (requestedRoute() !== current) window.history.replaceState(null, "", "#" + current);
      highlight();
    }
  });
  let firstLoad = true;
  article.addEventListener("load", () => {
    if (firstLoad) { firstLoad = false; current = initial; article.contentWindow.postMessage({ type: "ube-docs:load", path: initial }, "*"); highlight(); }
  });
})();
