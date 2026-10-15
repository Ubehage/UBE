(function () {
  "use strict";

  var data = window.UBE_DOCS;
  var tree = document.getElementById("topic-tree");
  var frame = document.getElementById("article-frame");
  var filter = document.getElementById("tree-filter");
  var clearFilter = document.getElementById("clear-filter");
  var filterStatus = document.getElementById("filter-status");
  var sidebar = document.getElementById("sidebar");
  var menuButton = document.getElementById("menu-button");
  var scrim = document.getElementById("scrim");
  var pathMap = Object.create(null);
  var itemMap = Object.create(null);
  var filterSnapshot = null;

  if (!data || !Array.isArray(data.sections)) {
    filterStatus.textContent = "Navigation data is unavailable. Use the direct links below.";
    document.getElementById("navigation-fallback").hidden = false;
    return;
  }

  function makeTextWithHighlight(element, value, query) {
    element.textContent = "";
    if (!query) {
      element.textContent = value;
      return;
    }
    var lower = value.toLocaleLowerCase();
    var index = lower.indexOf(query);
    if (index < 0) {
      element.textContent = value;
      return;
    }
    element.append(document.createTextNode(value.slice(0, index)));
    var mark = document.createElement("mark");
    mark.textContent = value.slice(index, index + query.length);
    element.append(mark, document.createTextNode(value.slice(index + query.length)));
  }

  function buildItem(item) {
    var li = document.createElement("li");
    li.className = "tree-item";
    li.dataset.id = item.id;
    li.dataset.title = item.title;
    li.dataset.search = [item.title].concat(item.aliases || []).join(" ").toLocaleLowerCase();
    itemMap[item.id] = li;

    var row = document.createElement("div");
    row.className = "tree-row";
    li.append(row);

    if (item.children && item.children.length) {
      var toggle = document.createElement("button");
      toggle.type = "button";
      toggle.className = "tree-toggle";
      toggle.setAttribute("aria-expanded", item.open ? "true" : "false");
      toggle.setAttribute("aria-label", (item.open ? "Collapse " : "Expand ") + item.title);
      row.append(toggle);
    } else {
      var spacer = document.createElement("span");
      spacer.className = "tree-toggle";
      spacer.setAttribute("aria-hidden", "true");
      row.append(spacer);
    }

    var title;
    if (item.path) {
      title = document.createElement("a");
      title.href = item.path;
      title.target = "article";
      title.className = "tree-link";
      title.dataset.path = item.path;
      pathMap[item.path] = item;
    } else {
      title = document.createElement("span");
      title.className = "tree-label";
      title.title = "Article not written yet";
    }
    title.textContent = item.title;
    row.append(title);

    if (item.children && item.children.length) {
      var children = document.createElement("ul");
      children.className = "tree-children";
      children.hidden = !item.open;
      item.children.forEach(function (child) { children.append(buildItem(child)); });
      li.append(children);
    }
    return li;
  }

  data.sections.forEach(function (section) { tree.append(buildItem(section)); });

  document.querySelectorAll(".top-nav [data-section]").forEach(function (link) {
    link.addEventListener("click", function (event) {
      event.preventDefault();
      if (filter.value) {
        filter.value = "";
        filter.dispatchEvent(new Event("input"));
      }
      var item = itemMap[link.dataset.section];
      if (!item) return;
      var toggle = item.querySelector(":scope > .tree-row > .tree-toggle[aria-expanded]");
      var children = item.querySelector(":scope > .tree-children");
      if (toggle && children) {
        toggle.setAttribute("aria-expanded", "true");
        children.hidden = false;
      }
      if (window.matchMedia("(max-width: 48rem)").matches) openNavigation();
      (toggle || item.querySelector(":scope > .tree-row > .tree-link")).focus();
    });
  });

  tree.addEventListener("click", function (event) {
    var toggle = event.target.closest(".tree-toggle[aria-expanded]");
    if (toggle) {
      var expanded = toggle.getAttribute("aria-expanded") === "true";
      toggle.setAttribute("aria-expanded", expanded ? "false" : "true");
      toggle.setAttribute("aria-label", (expanded ? "Expand " : "Collapse ") + toggle.nextElementSibling.textContent);
      toggle.closest(".tree-item").querySelector(":scope > .tree-children").hidden = expanded;
      return;
    }
    var link = event.target.closest("a[data-path]");
    if (link) {
      event.preventDefault();
      navigate(link.dataset.path, true);
      closeNavigation();
    }
  });

  function safePath(raw) {
    var path = String(raw || "").replace(/^#/, "");
    if (!path) return data.defaultPath;
    try { path = decodeURIComponent(path); } catch (error) { return "about/not-found.html"; }
    return Object.prototype.hasOwnProperty.call(pathMap, path) ? path : "about/not-found.html";
  }

  function navigate(rawPath, addHistory) {
    var path = safePath(rawPath);
    if (frame.getAttribute("src") !== path) frame.setAttribute("src", path);
    document.querySelectorAll(".tree-link[aria-current]").forEach(function (link) { link.removeAttribute("aria-current"); });
    var current = Array.from(tree.querySelectorAll(".tree-link[data-path]")).find(function (link) {
      return link.dataset.path === path;
    });
    if (current) {
      current.setAttribute("aria-current", "page");
      var parent = current.closest(".tree-item");
      while (parent) {
        var childList = parent.querySelector(":scope > .tree-children");
        var toggle = parent.querySelector(":scope > .tree-row > .tree-toggle[aria-expanded]");
        if (childList && toggle) {
          childList.hidden = false;
          toggle.setAttribute("aria-expanded", "true");
        }
        parent = parent.parentElement.closest(".tree-item");
      }
    }
    var nextHash = "#" + encodeURI(path);
    if (addHistory && window.location.hash !== nextHash) window.location.hash = nextHash;
  }

  function matchesItem(li, query) {
    var ownMatch = li.dataset.search.indexOf(query) >= 0;
    var descendantsMatch = false;
    Array.from(li.querySelectorAll(":scope > .tree-children > .tree-item")).forEach(function (child) {
      if (matchesItem(child, query)) descendantsMatch = true;
    });
    var visible = ownMatch || descendantsMatch;
    li.hidden = !visible;
    var titleNode = li.querySelector(":scope > .tree-row > .tree-link, :scope > .tree-row > .tree-label");
    makeTextWithHighlight(titleNode, li.dataset.title, ownMatch ? query : "");
    var children = li.querySelector(":scope > .tree-children");
    var toggle = li.querySelector(":scope > .tree-row > .tree-toggle[aria-expanded]");
    if (children && toggle && query) {
      children.hidden = !descendantsMatch;
      toggle.setAttribute("aria-expanded", descendantsMatch ? "true" : "false");
    }
    return visible;
  }

  function captureTreeState() {
    return {
      scrollTop: sidebar.scrollTop,
      expanded: Array.from(tree.querySelectorAll('.tree-toggle[aria-expanded="true"]')).map(function (button) {
        return button.closest(".tree-item").dataset.id;
      })
    };
  }

  function restoreTreeState(snapshot) {
    tree.querySelectorAll(".tree-item").forEach(function (li) {
      li.hidden = false;
      var titleNode = li.querySelector(":scope > .tree-row > .tree-link, :scope > .tree-row > .tree-label");
      makeTextWithHighlight(titleNode, li.dataset.title, "");
      var children = li.querySelector(":scope > .tree-children");
      var toggle = li.querySelector(":scope > .tree-row > .tree-toggle[aria-expanded]");
      if (children && toggle) {
        var expanded = snapshot.expanded.indexOf(li.dataset.id) >= 0;
        children.hidden = !expanded;
        toggle.setAttribute("aria-expanded", expanded ? "true" : "false");
      }
    });
    sidebar.scrollTop = snapshot.scrollTop;
  }

  filter.addEventListener("input", function () {
    var query = filter.value.trim().toLocaleLowerCase();
    clearFilter.hidden = !query;
    if (query && !filterSnapshot) filterSnapshot = captureTreeState();
    if (!query) {
      if (filterSnapshot) restoreTreeState(filterSnapshot);
      filterSnapshot = null;
      filterStatus.textContent = "";
      return;
    }
    var count = 0;
    Array.from(tree.children).forEach(function (li) { matchesItem(li, query); });
    tree.querySelectorAll(".tree-item").forEach(function (li) {
      if (!li.hidden && li.dataset.search.indexOf(query) >= 0) count += 1;
    });
    filterStatus.textContent = count ? count + (count === 1 ? " matching topic" : " matching topics") : "No matching topics";
  });

  clearFilter.addEventListener("click", function () {
    filter.value = "";
    filter.dispatchEvent(new Event("input"));
    filter.focus();
  });

  function openNavigation() {
    document.body.classList.add("nav-open");
    menuButton.setAttribute("aria-expanded", "true");
    filter.focus();
  }
  function closeNavigation() {
    if (!document.body.classList.contains("nav-open")) return;
    document.body.classList.remove("nav-open");
    menuButton.setAttribute("aria-expanded", "false");
    menuButton.focus();
  }
  menuButton.addEventListener("click", function () {
    document.body.classList.contains("nav-open") ? closeNavigation() : openNavigation();
  });
  scrim.addEventListener("click", closeNavigation);
  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") closeNavigation();
    if (event.key === "Tab" && document.body.classList.contains("nav-open")) {
      var focusable = Array.from(sidebar.querySelectorAll('a[href], button:not([disabled]), input:not([disabled])')).filter(function (node) { return !node.closest("[hidden]"); });
      if (!focusable.length) return;
      var first = focusable[0];
      var last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    }
  });

  window.addEventListener("message", function (event) {
    if (event.source !== frame.contentWindow || !event.data || event.data.type !== "ube-docs:navigate") return;
    navigate(event.data.path, true);
  });
  window.addEventListener("hashchange", function () { navigate(window.location.hash, false); });
  navigate(window.location.hash, false);
}());
