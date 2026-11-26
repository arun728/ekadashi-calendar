(() => {
  // Light or Dark, saved once picked. Until then the page follows the OS colour scheme.
  const key = 'apptinel-theme';
  const choices = ['light', 'dark'];
  const root = document.documentElement;
  const media = matchMedia('(prefers-color-scheme: dark)');
  let saved = null;
  try {
    const value = localStorage.getItem(key);
    if (choices.includes(value)) saved = value;
  } catch {
    // Without storage the switch still works for the current page.
  }

  const current = () => saved || (media.matches ? 'dark' : 'light');
  let buttons = [];
  function apply() {
    const theme = current();
    root.dataset.theme = theme;
    for (const button of buttons) {
      button.setAttribute('aria-checked', String(button.dataset.themeChoice === theme));
    }
  }
  apply();
  media.addEventListener('change', () => { if (!saved) apply(); });

  document.addEventListener('DOMContentLoaded', () => {
    const group = document.querySelector('[data-theme-switch]');
    if (!group) return;
    buttons = Array.from(document.querySelectorAll('[data-theme-choice]'));
    for (const button of buttons) {
      button.addEventListener('click', () => {
        saved = button.dataset.themeChoice;
        apply();
        try {
          localStorage.setItem(key, saved);
        } catch {
          // This page still reflects the requested mode.
        }
      });
    }
    apply();
    group.hidden = false;
  });
})();
