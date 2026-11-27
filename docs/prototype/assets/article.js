"use strict";
const pageNav = document.querySelector(".page-nav");
if (pageNav) {
  const updateNavHeight = () => {
    document.documentElement.style.setProperty("--page-nav-height", pageNav.getBoundingClientRect().height + "px");
  };
  updateNavHeight();
  if (typeof ResizeObserver !== "undefined") new ResizeObserver(updateNavHeight).observe(pageNav);
  else window.addEventListener("resize", updateNavHeight);
}
if (window.parent !== window) {
  window.parent.postMessage({ type: "help-page", page: window.location.pathname.split("/").pop() }, "*");
}
const copy = document.querySelector("#copy-example");
if (copy) copy.addEventListener("click", async () => {
  const code = document.querySelector("#example-source");
  try {
    await navigator.clipboard.writeText(code.textContent);
    copy.textContent = "Copied";
  } catch {
    const selection = window.getSelection();
    if (selection) {
      const range = document.createRange();
      range.selectNodeContents(code);
      selection.removeAllRanges();
      selection.addRange(range);
    }
    copy.textContent = "Selected — press Ctrl+C";
  }
});

function markSection() {
  const section = window.location.hash || "#overview";
  document.querySelectorAll('.page-nav a[href^="#"]').forEach(link => {
    if (link.getAttribute("href") === section) link.setAttribute("aria-current", "location");
    else link.removeAttribute("aria-current");
  });
}
window.addEventListener("hashchange", markSection);
markSection();
