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

(function() {
  const STORAGE_KEY_ONLY_APPTS = 'redmine_cal_only_appointments';
  const STORAGE_KEY_HIDE_PAST  = 'redmine_cal_hide_past_weeks';

  window.scrollToToday = function() {
    const todayElement = document.getElementById('today');
    if (todayElement) {
      todayElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  };

  document.addEventListener('DOMContentLoaded', function() {
    const urlParams = new URLSearchParams(window.location.search);
    let needsRedirect = false;

    // Sync "Show Customer Appointments Only" with localStorage if missing from URL
    if (!urlParams.has('only_appointments') && localStorage.getItem(STORAGE_KEY_ONLY_APPTS) === '1') {
      urlParams.set('only_appointments', '1');
      needsRedirect = true;
    }

    // Sync "Hide Past Weeks" with localStorage if missing from URL
    if (!urlParams.has('hide_past_weeks') && localStorage.getItem(STORAGE_KEY_HIDE_PAST) === '1') {
      urlParams.set('hide_past_weeks', '1');
      needsRedirect = true;
    }

    if (needsRedirect) {
      window.location.search = urlParams.toString();
      return;
    }

    // Automatically scroll to today if present and no hash anchor is in the URL
    if (!window.location.hash) {
      window.scrollToToday();
    }
  });

  window.toggleOnlyAppointments = function(checked) {
    const urlParams = new URLSearchParams(window.location.search);
    if (checked) {
      urlParams.set('only_appointments', '1');
      localStorage.setItem(STORAGE_KEY_ONLY_APPTS, '1');
    } else {
      urlParams.delete('only_appointments');
      localStorage.setItem(STORAGE_KEY_ONLY_APPTS, '0');
    }
    window.location.search = urlParams.toString();
  };

  window.toggleHidePastWeeks = function(checked) {
    const urlParams = new URLSearchParams(window.location.search);
    if (checked) {
      urlParams.set('hide_past_weeks', '1');
      localStorage.setItem(STORAGE_KEY_HIDE_PAST, '1');
    } else {
      urlParams.delete('hide_past_weeks');
      localStorage.setItem(STORAGE_KEY_HIDE_PAST, '0');
    }
    window.location.search = urlParams.toString();
  };
})();