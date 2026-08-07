document.addEventListener('DOMContentLoaded', function() {
  document.addEventListener('click', function(e) {
    const clickedBlock = e.target.closest('.appointment-block');
    const clickedLink = e.target.closest('a');

    // Allow standard links (like subject title or avatar links) to navigate normally
    if (clickedLink) return;

    // Close any other open tooltips across the calendar
    document.querySelectorAll('.appointment-block.open').forEach(function(block) {
      if (block !== clickedBlock) {
        block.classList.remove('open');
      }
    });

    // Toggle the clicked appointment block's tooltip
    if (clickedBlock) {
      e.stopPropagation();
      clickedBlock.classList.toggle('open');
    }
  });
});