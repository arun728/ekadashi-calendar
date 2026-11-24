(() => {
  // System follows the OS colour scheme live; Light and Dark override it and persist.
  const key = 'apptinel-theme';
  const choices = ['system', 'light', 'dark'];
  const root = document.documentElement;
  const media = matchMedia('(prefers-color-scheme: dark)');
  let choice = 'system';
  try {
    const saved = localStorage.getItem(key);
    if (choices.includes(saved)) choice = saved;
  } catch {
    // Without storage the switch still works for the current page.
  }

  function apply() {
    root.dataset.theme = choice === 'system' ? (media.matches ? 'dark' : 'light') : choice;
  }
  apply();
  media.addEventListener('change', () => { if (choice === 'system') apply(); });

  document.addEventListener('DOMContentLoaded', () => {
    const group = document.querySelector('[data-theme-switch]');
    if (!group) return;
    const buttons = Array.from(document.querySelectorAll('[data-theme-choice]'));

    function update() {
      for (const button of buttons) {
        button.setAttribute('aria-checked', String(button.dataset.themeChoice === choice));
      }
    }

    for (const button of buttons) {
      button.addEventListener('click', () => {
        choice = button.dataset.themeChoice;
        apply();
        update();
        try {
          localStorage.setItem(key, choice);
        } catch {
          // This page still reflects the requested mode.
        }
      });
    }
    update();
    group.hidden = false;
  });
})();
