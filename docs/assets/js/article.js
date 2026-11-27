"use strict";
(() => {
  const root = document.documentElement;
  const path = root.dataset.docPath;
  const docRoot = new URL(root.dataset.docRoot || "./", window.location.href);
  const framed = window.parent !== window;
  const nav = document.querySelector(".page-nav");
  const sectionLinks = [...document.querySelectorAll('.page-nav a[href^="#"]')];
  function updateHeight() {
    if (nav) root.style.setProperty("--page-nav-height", nav.getBoundingClientRect().height + "px");
  }
  updateHeight();
  if (nav && typeof ResizeObserver !== "undefined") new ResizeObserver(updateHeight).observe(nav);
  else window.addEventListener("resize", updateHeight);
  function announce() {
    if (framed && path) window.parent.postMessage({ type: "ube-docs:page", path: path + window.location.hash }, "*");
  }
  function markSection() {
    let selected = "#overview";
    const top = (nav?.getBoundingClientRect().height || 0) + 30;
    for (const link of sectionLinks) {
      const target = document.getElementById(link.hash.slice(1));
      if (target && target.getBoundingClientRect().top <= top) selected = link.hash;
    }
    // A final section can be too short to reach the sticky navigation offset.
    // At the bottom of a scrolled page, it is still the current section.
    if (window.scrollY > 0 && Math.ceil(window.scrollY + window.innerHeight) >= root.scrollHeight - 2 && sectionLinks.length) {
      selected = sectionLinks[sectionLinks.length - 1].hash;
    }
    for (const link of sectionLinks) {
      if (link.hash === selected) link.setAttribute("aria-current", "location");
      else link.removeAttribute("aria-current");
    }
  }
  let pending = false;
  window.addEventListener("scroll", () => {
    if (pending) return;
    pending = true;
    window.requestAnimationFrame(() => { pending = false; markSection(); });
  }, { passive: true });
  window.addEventListener("hashchange", () => { announce(); markSection(); });
  window.addEventListener("message", event => {
    if (!framed || event.source !== window.parent || event.data?.type !== "ube-docs:load") return;
    const route = event.data.path;
    if (typeof route !== "string" || !/^[a-z0-9/-]+\.html(?:#[A-Za-z][\w:.-]*)?$/.test(route) || route.includes("..")) return;
    const destination = new URL(route, docRoot);
    if (destination.href !== window.location.href) window.location.replace(destination.href);
    else { const target = document.getElementById(destination.hash.slice(1) || "overview"); if (target) target.scrollIntoView(); }
  });
  document.addEventListener("click", event => {
    const link = event.target.closest("a[href]");
    if (!link || !framed || event.defaultPrevented || event.button !== 0 || event.ctrlKey || event.metaKey || event.altKey || event.shiftKey || link.hasAttribute("download") || link.target === "_blank" || link.target === "_top") return;
    const url = new URL(link.href, window.location.href);
    if (!url.href.startsWith(docRoot.href) || !url.pathname.endsWith(".html")) return;
    if (url.pathname === window.location.pathname) return;
    event.preventDefault();
    window.parent.postMessage({ type: "ube-docs:navigate", path: url.href.slice(docRoot.href.length) }, "*");
  });
  for (const code of document.querySelectorAll("pre > code")) {
    const pre = code.parentElement;
    const wrapper = document.createElement("div");
    wrapper.className = "code-block";
    pre.before(wrapper); wrapper.append(pre);
    const button = document.createElement("button");
    button.type = "button"; button.className = "copy-code";
    button.textContent = "Copy"; button.setAttribute("aria-label", "Copy code");
    button.setAttribute("aria-live", "polite"); wrapper.prepend(button);
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(code.textContent);
        button.textContent = "Copied";
      } catch {
        const selection = window.getSelection();
        if (selection) {
          const range = document.createRange(); range.selectNodeContents(code);
          selection.removeAllRanges(); selection.addRange(range);
        }
        button.textContent = "Selected — press Ctrl+C";
      }
    });
  }
  markSection();
  // Wait until the shell's initial-load handler can send a bookmarked route.
  window.addEventListener("load", announce, { once: true });
})();
