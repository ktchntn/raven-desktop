// RAVEN startpage behaviour: clock, search (bangs, hosts/IPs go straight there), link groups.
(() => {
  const $ = id => document.getElementById(id);
  const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  function tick() {
    const now = new Date();
    const h = now.getHours() % 12 || 12;
    $("hm").innerHTML = `${h}<span class="colon">:</span>${String(now.getMinutes()).padStart(2, "0")}`;
    $("ampm").textContent = now.getHours() < 12 ? "AM" : "PM";
    $("date").textContent = `${DAYS[now.getDay()]} · ${now.getDate()} ${MONTHS[now.getMonth()]} ${now.getFullYear()}`;
  }
  tick();
  setInterval(tick, 1000);

  // Link groups
  const groups = $("groups");
  for (const g of GROUPS) {
    const card = document.createElement("div");
    card.className = "group";
    const title = document.createElement("h2");
    title.textContent = g.title;
    card.appendChild(title);
    for (const [name, url] of g.links) {
      const a = document.createElement("a");
      a.href = url;
      a.textContent = name;
      a.title = url;
      card.appendChild(a);
    }
    groups.appendChild(card);
  }

  // Bang chips
  const bangs = $("bangs");
  for (const [key, [label]] of Object.entries(BANGS)) {
    const chip = document.createElement("button");
    chip.type = "button";
    chip.dataset.bang = key;
    chip.textContent = "!" + key;
    chip.title = label;
    chip.addEventListener("click", () => {
      const q = $("q");
      q.value = `!${key} ` + q.value.replace(/^!\S*\s*/, "");
      q.focus();
      update();
    });
    bangs.appendChild(chip);
  }

  const HOST = /^(?:[a-z][a-z0-9+.-]*:\/\/\S+|localhost(?::\d+)?(?:\/\S*)?|\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?(?:\/\S*)?|(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?(?:\/\S*)?)$/i;

  // "!edb apache 2.4" or "apache 2.4 !edb"; unknown bangs are searched as typed.
  function parse(text) {
    const t = text.trim();
    let m = t.match(/^!(\S+)(?:\s+(.*))?$/);
    if (m && BANGS[m[1]]) return { key: m[1], query: m[2] || "" };
    m = t.match(/^(.*\S)\s+!(\S+)$/);
    if (m && BANGS[m[2]]) return { key: m[2], query: m[1] };
    return { key: DEFAULT_BANG, query: t };
  }

  function update() {
    const { key, query } = parse($("q").value);
    const direct = key === DEFAULT_BANG && HOST.test(query.trim()) && !/\s/.test(query.trim());
    $("engine").textContent = direct ? "go to" : BANGS[key][0];
    $("search").classList.toggle("direct", direct);
    for (const chip of bangs.children) chip.classList.toggle("on", chip.dataset.bang === key && !direct);
  }

  $("q").addEventListener("input", update);
  $("search").addEventListener("submit", e => {
    e.preventDefault();
    const { key, query } = parse($("q").value);
    const q = query.trim();
    if (!q) return;
    if (key === DEFAULT_BANG && HOST.test(q) && !/\s/.test(q)) {
      location.href = /^[a-z][a-z0-9+.-]*:\/\//i.test(q) ? q : "http://" + q;
      return;
    }
    location.href = BANGS[key][1].replace("%s", encodeURIComponent(q));
  });

  // Type anywhere to search; Esc clears.
  document.addEventListener("keydown", e => {
    const q = $("q");
    if (e.key === "Escape") { q.value = ""; update(); q.blur(); return; }
    if (document.activeElement !== q && e.key.length === 1 && !e.ctrlKey && !e.metaKey && !e.altKey) q.focus();
  });
  update();
  $("q").focus();
})();
