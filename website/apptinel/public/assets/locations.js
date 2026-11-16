(() => {
  const catalog = document.querySelector('#location-catalog');
  const query = document.querySelector('#city-query');
  const zone = document.querySelector('#zone-filter');
  const results = document.querySelector('#city-results');
  const status = document.querySelector('#catalog-status');
  const more = document.querySelector('#city-more');
  const pageSize = 25;
  const number = new Intl.NumberFormat('en');

  let cities;
  let matches;
  let shown = 0;
  let loading = false;

  function showNextPage() {
    const next = matches.slice(shown, shown + pageSize);
    const rows = document.createDocumentFragment();
    for (const [, name, , country, , , timeZone] of next) {
      const item = document.createElement('li');
      item.textContent = name + ' · ' + country + ' · ' + timeZone;
      rows.append(item);
    }
    results.append(rows);
    shown += next.length;
    more.hidden = shown >= matches.length;
    status.textContent = matches.length
      ? 'Showing ' + number.format(shown) + ' of ' + number.format(matches.length) + ' cities.'
      : 'No matching cities. Try a different search or time zone.';
  }

  function filterCities() {
    const term = query.value.trim().toLowerCase();
    const selectedZone = zone.value;
    matches = cities.filter(({ row, text }) =>
      (!selectedZone || row[6] === selectedZone) && (text.includes(term) || row[3].toLowerCase() === term)
    ).map(({ row }) => row);
    results.replaceChildren();
    shown = 0;
    showNextPage();
  }

  async function loadCatalog() {
    if (!catalog.open || cities || loading) return;
    loading = true;
    status.textContent = 'Loading the location catalog…';
    try {
      const response = await fetch(catalog.dataset.catalog);
      if (!response.ok) throw new Error('Catalog unavailable');
      const data = await response.json();
      cities = data.cities.map((row) => ({
        row,
        text: [row[1], row[2], row[6]].join(' ').toLowerCase()
      }));
      for (const id of data.zones) {
        zone.add(new Option(id, id));
      }
      query.disabled = false;
      zone.disabled = false;
      filterCities();
    } catch {
      cities = undefined;
      status.textContent = 'The catalog could not load. Reopen it to retry or use the download link.';
    } finally {
      loading = false;
    }
  }

  catalog.addEventListener('toggle', loadCatalog);
  query.addEventListener('input', filterCities);
  zone.addEventListener('change', filterCities);
  more.addEventListener('click', () => {
    const previousCount = shown;
    showNextPage();
    const first = results.children[previousCount];
    if (first) {
      first.tabIndex = -1;
      first.focus();
    }
  });
  loadCatalog();
})();
