"use strict";
(() => {
  const filter = document.querySelector("#topic-filter");
  const clear = document.querySelector("#clear-filter");
  const status = document.querySelector("#filter-status");
  const tree = document.querySelector("#topic-tree");
  const entries = [...tree.querySelectorAll("li[data-search]")];
  const branches = [...tree.querySelectorAll("details")];
  let snapshot = null;
  function applyFilter() {
    const query = filter.value.trim().toLowerCase();
    if (query && !snapshot) snapshot = { open: branches.map(branch => branch.open), scroll: window.scrollY };
    let count = 0;
    for (const entry of entries) {
      entry.hidden = !entry.dataset.search.toLowerCase().includes(query);
      if (!entry.hidden) count++;
    }
    for (const branch of [...branches].reverse()) {
      const matches = [...branch.querySelectorAll("li[data-search]")].some(entry => !entry.hidden);
      branch.hidden = !matches;
      if (query && matches) branch.open = true;
    }
    if (!query && snapshot) {
      branches.forEach((branch, index) => { branch.open = snapshot.open[index]; });
      window.scrollTo(0, snapshot.scroll);
      snapshot = null;
    }
    clear.hidden = !query;
    status.textContent = query ? count ? `${count} matching ${count === 1 ? "topic" : "topics"}` : "No matching topics. Clear the filter to see all topics." : "";
  }
  filter.addEventListener("input", applyFilter);
  clear.addEventListener("click", () => { filter.value = ""; applyFilter(); filter.focus(); });
  function select(path) {
    for (const link of tree.querySelectorAll("a[data-path]")) {
      const current = link.dataset.path === path;
      if (current) {
        link.setAttribute("aria-current", "page");
        let ancestor = link.parentElement;
        while (ancestor && ancestor !== tree) {
          if (ancestor.tagName === "DETAILS") ancestor.open = true;
          ancestor = ancestor.parentElement;
        }
      } else link.removeAttribute("aria-current");
    }
  }
  window.addEventListener("message", event => {
    if (event.source === window.parent && event.data?.type === "ube-docs:selection" && typeof event.data.path === "string") select(event.data.path);
  });
  document.addEventListener("click", event => {
    const link = event.target.closest("a[data-path]");
    if (!link || window.parent === window || event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    window.parent.postMessage({ type: "ube-docs:navigate", path: link.dataset.path }, "*");
  });
  applyFilter();
})();
