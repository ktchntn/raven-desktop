// RAVEN startpage: link groups and search bangs. Edit here, then run ../make-startpage.py.
const GROUPS = [
  { title: "Kali", links: [
    ["OffSec Portal", "https://portal.offsec.com/"],
    ["Kali Tools", "https://www.kali.org/tools/"],
    ["Kali Docs", "https://www.kali.org/docs/"],
    ["Kali Forums", "https://forums.kali.org/"],
  ]},
  { title: "Resources", links: [
    ["HackTricks", "https://book.hacktricks.wiki/"],
    ["HackIndex", "https://hackindex.io/"],
    ["WADComs", "https://wadcoms.github.io/"],
    ["PayloadsAllTheThings", "https://swisskyrepo.github.io/PayloadsAllTheThings/"],
  ]},
  { title: "Exploits", links: [
    ["Exploit-DB", "https://www.exploit-db.com/"],
    ["Google Hacking DB", "https://www.exploit-db.com/google-hacking-database"],
    ["GTFOBins", "https://gtfobins.github.io/"],
    ["LOLBAS", "https://lolbas-project.github.io/"],
    ["Reverse Shells", "https://www.revshells.com/"],
  ]},
  { title: "Tools", links: [
    ["CyberChef", "https://gchq.github.io/CyberChef/"],
    ["OffSecKit", "https://offseckit.com/"],
    ["Hashcat hashes", "https://hashcat.net/wiki/doku.php?id=example_hashes"],
    ["CrackStation", "https://crackstation.net/"],
    ["explainshell", "https://explainshell.com/"],
  ]},
];

// !bang -> [label, URL with %s for the query]
const BANGS = {
  g:    ["google", "https://www.google.com/search?q=%s"],
  d:    ["duckduckgo", "https://duckduckgo.com/?q=%s"],
  edb:  ["exploit-db", "https://www.exploit-db.com/search?q=%s"],
  gtfo: ["gtfobins", "https://gtfobins.github.io/#%s"],
  lol:  ["lolbas", "https://lolbas-project.github.io/#%s"],
  ht:   ["hacktricks", "https://www.google.com/search?q=site%3Abook.hacktricks.wiki+%s"],
  cve:  ["nvd", "https://nvd.nist.gov/vuln/search/results?form_type=Basic&results_type=overview&search_type=all&query=%s"],
  gh:   ["github", "https://github.com/search?type=repositories&q=%s"],
};
const DEFAULT_BANG = "g";
