// RAVEN for Firefox: prefs applied at every start.
// Load chrome/userChrome.css and chrome/userContent.css.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Dark everywhere: the browser chrome, and sites that offer a dark scheme.
user_pref("layout.css.prefers-color-scheme.content-override", 0);
user_pref("browser.theme.content-theme", 0);
user_pref("browser.theme.toolbar-theme", 0);
// Pure black while a page loads, not white.
user_pref("browser.display.background_color.dark", "#000000");
// Compact-ish density with room for the rounded tabs.
user_pref("browser.uidensity", 0);
user_pref("browser.tabs.inTitlebar", 1);

// RAVEN startpage (raven/startpage): an unsigned local add-on, auto-enabled from the profile.
// Firefox ESR honours the signature switch (release Firefox does not).
user_pref("xpinstall.signatures.required", false);
user_pref("extensions.autoDisableScopes", 0);
