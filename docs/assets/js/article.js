(function () {
  "use strict";

  var framed = window.self !== window.top;
  if (framed) {
    document.documentElement.classList.add("inside-shell");
  }

  document.addEventListener("click", function (event) {
    var link = event.target.closest("a[data-doc-path]");
    if (!link || !framed || event.defaultPrevented || event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) {
      return;
    }
    event.preventDefault();
    window.parent.postMessage({ type: "ube-docs:navigate", path: link.getAttribute("data-doc-path") }, "*");
  });

  document.querySelectorAll("pre > code").forEach(function (code) {
    var pre = code.parentElement;
    var wrapper = document.createElement("div");
    wrapper.className = "code-block";
    pre.parentNode.insertBefore(wrapper, pre);
    wrapper.append(pre);

    var button = document.createElement("button");
    button.type = "button";
    button.className = "copy-code";
    button.textContent = "Copy";
    button.setAttribute("aria-label", "Copy code example");
    wrapper.insertBefore(button, pre);

    button.addEventListener("click", function () {
      function showResult(copied) {
        button.textContent = copied ? "Copied" : "Select and copy";
        window.setTimeout(function () { button.textContent = "Copy"; }, 1800);
      }

      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(code.textContent).then(function () { showResult(true); }, function () { showResult(false); });
        return;
      }

      var selection = window.getSelection();
      var range = document.createRange();
      range.selectNodeContents(code);
      selection.removeAllRanges();
      selection.addRange(range);
      var copied = false;
      try { copied = document.execCommand("copy"); } catch (error) { copied = false; }
      if (copied) selection.removeAllRanges();
      showResult(copied);
    });
  });

  var articleId = document.documentElement.getAttribute("data-article-id") || "";
  if (!/^language\.words\.[a-z]$/.test(articleId)) return;

  var intrinsicTypes = ["Any", "Boolean", "Byte", "Currency", "Date", "Decimal", "Double", "Integer", "IntPtr", "Long", "LongLong", "Object", "Single", "String", "UIntPtr", "Variant"];
  var libraryTypes = ["AtomicBoolean", "AtomicLong", "AtomicLongLong", "AtomicObject", "MessageQueue", "Semaphore", "ThreadEvent"];
  var libraryFunctions = ["CollectGarbage", "CreateSemaphore", "CreateThreadEvent", "CurrentThreadId", "IsEmpty", "IsNull", "ThreadIsAlive", "ThreadRequestStop", "ThreadStopRequested", "ThreadWait"];
  var libraryProcedures = ["ThreadYield"];
  var operators = ["AddressOf", "And", "AndAlso", "Eqv", "Imp", "Is", "IsNot", "Like", "Mod", "Not", "Or", "OrElse", "TypeOf", "Xor"];
  var literals = ["Empty", "False", "Nothing", "Null", "True"];
  var expressions = ["Me", "New"];

  function includes(items, value) {
    return items.indexOf(value) !== -1;
  }

  function kindFor(word) {
    if (includes(intrinsicTypes, word)) return "Intrinsic type";
    if (includes(libraryTypes, word)) return "Core-library type";
    if (includes(libraryFunctions, word)) return "Core-library function";
    if (includes(libraryProcedures, word)) return "Core-library Sub";
    if (includes(operators, word)) return "Operator";
    if (includes(literals, word)) return "Literal";
    if (includes(expressions, word)) return "Expression";
    return "Keyword";
  }

  document.querySelectorAll(".word-list > li").forEach(function (item) {
    var link = item.querySelector("a");
    if (!link || item.querySelector(".word-kind")) return;
    var kind = document.createElement("span");
    kind.className = "word-kind";
    kind.textContent = kindFor(link.textContent.trim());
    item.appendChild(kind);
  });

  document.querySelectorAll(".word-list, .card-grid").forEach(function (list) {
    Array.prototype.slice.call(list.children).sort(function (left, right) {
      var leftName = (left.querySelector("strong, a") || left).textContent.trim();
      var rightName = (right.querySelector("strong, a") || right).textContent.trim();
      return leftName.localeCompare(rightName, undefined, { sensitivity: "base" });
    }).forEach(function (item) { list.appendChild(item); });
  });
}());
