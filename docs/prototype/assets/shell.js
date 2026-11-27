"use strict";
const article = document.querySelector('iframe[name="article"]');
const search = document.querySelector('iframe[name="search"]');
let currentPage = "if.html";
window.addEventListener("message", event => {
  if (event.source !== article.contentWindow || event.data?.type !== "help-page") return;
  if (typeof event.data.page !== "string" || !/^[a-z-]+\.html$/.test(event.data.page)) return;
  currentPage = event.data.page;
  search.contentWindow.postMessage({ type: "help-selection", page: currentPage }, "*");
});
search.addEventListener("load", () => search.contentWindow.postMessage({ type: "help-selection", page: currentPage }, "*"));
