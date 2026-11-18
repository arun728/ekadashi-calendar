(() => {
  const key = 'apptinel-theme';
  const root = document.documentElement;
  try {
    if (localStorage.getItem(key) === 'light') root.dataset.theme = 'light';
  } catch {
    // The switch still works for the current page when storage is unavailable.
  }

  document.addEventListener('DOMContentLoaded', () => {
    const button = document.querySelector('[data-theme-toggle]');
    if (!button) return;

    function updateButton() {
      button.setAttribute('aria-pressed', String(root.dataset.theme === 'light'));
    }

    button.addEventListener('click', () => {
      root.dataset.theme = root.dataset.theme === 'light' ? 'dark' : 'light';
      updateButton();
      try {
        localStorage.setItem(key, root.dataset.theme);
      } catch {
        // This page still reflects the requested mode.
      }
    });
    updateButton();
    button.hidden = false;
  });
})();
