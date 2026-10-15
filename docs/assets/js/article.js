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
}());
