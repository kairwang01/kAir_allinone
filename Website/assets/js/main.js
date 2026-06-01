/* ==========================================================================
   kAir — Interactions
   No dependencies. Progressive enhancement: the page is fully readable
   with JS disabled; this only adds behavior.
   ========================================================================== */
(function () {
  "use strict";

  const prefersReduced =
    window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* --- Sticky nav state ------------------------------------------------- */
  const nav = document.querySelector(".nav");
  if (nav) {
    const onScroll = function () {
      nav.classList.toggle("is-scrolled", window.scrollY > 8);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  /* --- Mobile menu ------------------------------------------------------ */
  const menuBtn = document.querySelector("[data-menu-btn]");
  const mobileMenu = document.querySelector("[data-mobile-menu]");
  if (menuBtn && mobileMenu) {
    const setOpen = function (open) {
      mobileMenu.classList.toggle("is-open", open);
      menuBtn.setAttribute("aria-expanded", String(open));
    };
    menuBtn.addEventListener("click", function () {
      setOpen(!mobileMenu.classList.contains("is-open"));
    });
    mobileMenu.querySelectorAll("a").forEach(function (a) {
      a.addEventListener("click", function () { setOpen(false); });
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") setOpen(false);
    });
  }

  /* --- Scroll reveal ---------------------------------------------------- */
  const revealEls = document.querySelectorAll(".reveal");
  if (revealEls.length) {
    if (prefersReduced || !("IntersectionObserver" in window)) {
      revealEls.forEach(function (el) { el.classList.add("is-visible"); });
    } else {
      const io = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            io.unobserve(entry.target);
          }
        });
      }, { rootMargin: "0px 0px -8% 0px", threshold: 0.12 });
      revealEls.forEach(function (el) { io.observe(el); });
    }
  }

  /* --- FAQ accordion ---------------------------------------------------- */
  document.querySelectorAll(".accordion__trigger").forEach(function (trigger) {
    const panel = document.getElementById(trigger.getAttribute("aria-controls"));
    if (!panel) return;
    trigger.addEventListener("click", function () {
      const expanded = trigger.getAttribute("aria-expanded") === "true";
      trigger.setAttribute("aria-expanded", String(!expanded));
      panel.style.maxHeight = expanded ? "0px" : panel.scrollHeight + "px";
    });
    // keep height correct on language change / resize
    const refresh = function () {
      if (trigger.getAttribute("aria-expanded") === "true") {
        panel.style.maxHeight = panel.scrollHeight + "px";
      }
    };
    document.addEventListener("kair:langchange", function () { setTimeout(refresh, 30); });
    window.addEventListener("resize", refresh, { passive: true });
  });

  /* --- Device subtle tilt (desktop, pointer) ---------------------------- */
  if (!prefersReduced && window.matchMedia("(pointer:fine)").matches) {
    document.querySelectorAll("[data-tilt]").forEach(function (el) {
      const max = 5;
      el.style.transition = "transform 0.3s cubic-bezier(0.22,1,0.36,1)";
      el.addEventListener("pointermove", function (e) {
        const r = el.getBoundingClientRect();
        const px = (e.clientX - r.left) / r.width - 0.5;
        const py = (e.clientY - r.top) / r.height - 0.5;
        el.style.transform =
          "perspective(900px) rotateY(" + (px * max) + "deg) rotateX(" + (-py * max) + "deg)";
      });
      el.addEventListener("pointerleave", function () {
        el.style.transform = "perspective(900px) rotateY(0) rotateX(0)";
      });
    });
  }

  /* --- Waitlist form ---------------------------------------------------- */
  const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  const t = function (key) {
    return window.kAirI18n ? window.kAirI18n.t(key, document.documentElement.lang === "zh-Hans" ? "zh" : "en") : key;
  };

  document.querySelectorAll("[data-waitlist]").forEach(function (form) {
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      const input = form.querySelector('input[type="email"]');
      const email = (input.value || "").trim();
      if (!EMAIL_RE.test(email)) {
        input.setAttribute("aria-invalid", "true");
        input.focus();
        showError(form);
        return;
      }
      input.removeAttribute("aria-invalid");

      /* No backend yet. Persist locally so the visitor isn't lost, and
         expose a hook for a real endpoint (see Website/README.md).
         To wire a provider, POST `email` here and await the response. */
      try {
        const list = JSON.parse(localStorage.getItem("kair-waitlist") || "[]");
        if (list.indexOf(email) === -1) list.push(email);
        localStorage.setItem("kair-waitlist", JSON.stringify(list));
      } catch (err) {}

      const success = form.parentNode.querySelector("[data-waitlist-success]");
      form.hidden = true;
      if (success) {
        success.hidden = false;
        const live = success.querySelector("[data-success-text]");
        if (live) live.textContent = t("form.success");
      }
    });
  });

  function showError(form) {
    let err = form.parentNode.querySelector("[data-form-error]");
    if (!err) {
      err = document.createElement("p");
      err.setAttribute("data-form-error", "");
      err.className = "form-note";
      err.style.color = "#c0564c";
      form.parentNode.insertBefore(err, form.nextSibling);
    }
    err.textContent = t("form.invalid");
    setTimeout(function () { if (err) err.textContent = ""; }, 4000);
  }

  /* --- Footer year ------------------------------------------------------ */
  document.querySelectorAll("[data-year]").forEach(function (el) {
    el.textContent = "2026";
  });
})();
