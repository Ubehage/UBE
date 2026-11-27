"use strict";
const field = document.querySelector("#query");
const entries = Array.from(document.querySelectorAll("#topics li"));
const groups = Array.from(document.querySelectorAll("#topics details"));
const count = document.querySelector("#count");
const clear = document.querySelector("#clear");
let savedExpansion = null;
function filterTopics() {
  const query = field.value.trim().toLowerCase();
  if (query && savedExpansion === null) savedExpansion = groups.map(group => group.open);
  let visible = 0;
  entries.forEach(entry => {
    entry.hidden = !(entry.textContent + " " + (entry.dataset.aliases || "")).toLowerCase().includes(query);
    if (!entry.hidden) visible++;
  });
  groups.forEach((group, index) => {
    group.hidden = !Array.from(group.querySelectorAll("li")).some(entry => !entry.hidden);
    if (query && !group.hidden) group.open = true;
    else if (!query && savedExpansion !== null) group.open = savedExpansion[index];
  });
  if (!query) savedExpansion = null;
  clear.hidden = !query;
  count.textContent = !query ? "" : visible ? visible + (visible === 1 ? " topic" : " topics") : "No matching topics. Clear the search to see all topics.";
}
field.addEventListener("input", filterTopics);
clear.addEventListener("click", () => { field.value = ""; filterTopics(); field.focus(); });
window.addEventListener("message", event => {
  if (event.source !== window.parent || event.data?.type !== "help-selection") return;
  const selected = entries.find(entry => entry.querySelector("a").getAttribute("href") === event.data.page);
  if (!selected) return;
  entries.forEach(entry => entry.querySelector("a").removeAttribute("aria-current"));
  selected.querySelector("a").setAttribute("aria-current", "page");
});
filterTopics();
