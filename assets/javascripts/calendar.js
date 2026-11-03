document.addEventListener('DOMContentLoaded', function() {
  document.addEventListener('click', function(e) {
    const clickedBlock = e.target.closest('.appointment-block');
    const clickedLink = e.target.closest('a');

    // Allow standard links (like subject title or avatar links) to navigate normally
    if (clickedLink) return;

    // Clicks inside an open tooltip (e.g. selecting a phone number to copy) leave it open
    if (e.target.closest('.appointment-block .tip')) return;

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

(function() {
  window.scrollToToday = function() {
    const todayElement = document.getElementById('today');
    if (todayElement) {
      todayElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  };

  document.addEventListener('DOMContentLoaded', function() {
    // Automatically scroll to today if present and no hash anchor is in the URL
    if (!window.location.hash) {
      window.scrollToToday();
    }
  });

  // The toggles are kept in the session (CalendarsControllerPatch), so turning one off sends 0 rather
  // than leaving it out
  function setToggle(name, checked) {
    const urlParams = new URLSearchParams(window.location.search);
    urlParams.set(name, checked ? '1' : '0');
    window.location.search = urlParams.toString();
  }

  window.toggleOnlyAppointments = function(checked) {
    setToggle('only_appointments', checked);
  };

  window.toggleHidePastWeeks = function(checked) {
    setToggle('hide_past_weeks', checked);
  };
})();
