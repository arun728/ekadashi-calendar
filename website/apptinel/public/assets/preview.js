const player = document.querySelector('.app-preview-player');
if (player && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
  player.play().catch(() => {
    // Browser autoplay policies may leave the player ready for a manual play.
  });
}
