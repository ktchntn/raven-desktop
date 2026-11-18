// RAVEN: recognise hashes / tickets / tokens in clipboard history (raven, not upstream).
// Works on cliphist's preview: one line (newlines become spaces), at most 100 characters, so the
// long formats are matched by how they start. Keep in step with RULES in bin/raven-hash.
.pragma library

// [pattern, label, hashcat mode (-1: john only), slug for ~/Loot/hashes/<mode>-<slug>.txt]
const RULES = [
    [/^\$krb5tgs\$23\$/, "KRB5 TGS", 13100, "krb5tgs"],
    [/^\$krb5tgs\$17\$/, "KRB5 TGS AES128", 19600, "krb5tgs-aes128"],
    [/^\$krb5tgs\$18\$/, "KRB5 TGS AES256", 19700, "krb5tgs-aes256"],
    [/^\$krb5asrep\$23\$/, "AS-REP", 18200, "asrep"],
    [/^\$DCC2\$\d+#[^#\s]+#[0-9a-f]{32}/i, "DCC2", 2100, "dcc2"],
    [/^\$2[abxy]?\$\d{2}\$[.\/A-Za-z0-9]{53}$/, "bcrypt", 3200, "bcrypt"],
    [/^\$6\$[^$\s]{1,16}\$[.\/A-Za-z0-9]{20}/, "sha512crypt", 1800, "sha512crypt"],
    [/^\$5\$[^$\s]{1,16}\$[.\/A-Za-z0-9]{20}/, "sha256crypt", 7400, "sha256crypt"],
    [/^\$1\$[^$\s]{1,8}\$[.\/A-Za-z0-9]{22}$/, "md5crypt", 500, "md5crypt"],
    [/^\$y\$[^$\s]+\$[^$\s]+\$[.\/A-Za-z0-9]{20}/, "yescrypt", -1, "yescrypt"],
    [/^[^\s:]+::[^\s:]*:[0-9a-f]{16}:[0-9a-f]{32}:[0-9a-f]/i, "NetNTLMv2", 5600, "netntlmv2"],
    [/^[^\s:]+::[^\s:]*:[0-9a-f]{48}:[0-9a-f]{48}:[0-9a-f]{16}/i, "NetNTLMv1", 5500, "netntlmv1"],
    [/^[^\s:]+:\d+:[0-9a-f]{32}:[0-9a-f]{32}:::/i, "NTLM", 1000, "ntlm"],
    [/^eyJ[\w-]{10,}\.eyJ[\w-]+/, "JWT", 16500, "jwt"],
    [/^[0-9a-f]{32}$/i, "NTLM / MD5", 1000, "ntlm"],
    [/^[0-9a-f]{40}$/i, "SHA1", 100, "sha1"],
    [/^[0-9a-f]{64}$/i, "SHA256", 1400, "sha256"],
];

function identify(text) {
    const t = String(text ?? "").trim();
    for (const [pattern, label, mode, slug] of RULES)
        if (pattern.test(t))
            return { label: label, mode: mode, slug: slug };
    return null;
}

function chip(hash) {
    return hash ? hash.label + " · " + (hash.mode >= 0 ? hash.mode : "john") : "";
}
