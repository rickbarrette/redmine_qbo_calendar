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
    // Line up today's day number near the top of the window. Centering the whole cell hid the number
    // above the window when the day is busy (tall cell).
    const todayElement = document.getElementById('today');
    if (todayElement) {
      const target = todayElement.querySelector('.day-num') || todayElement;
      const top = target.getBoundingClientRect().top + window.scrollY - 10;
      window.scrollTo({ top: Math.max(top, 0), behavior: 'smooth' });
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

  // The checkbox at the start of each week: flags it "no new work" (circled in red) without reloading
  window.toggleNoWorkWeek = function(checkbox, week) {
    const calendar = checkbox.closest('ul.cal');
    const token = document.querySelector('meta[name="csrf-token"]');
    const body = new URLSearchParams({ week: week, flagged: checkbox.checked ? '1' : '0' });
    const cells = calendar.querySelectorAll('li[data-no-work-week="' + week + '"]');
    checkbox.disabled = true;

    fetch(calendar.dataset.noWorkWeeksUrl, {
      method: 'POST',
      headers: { 'Accept': 'application/json', 'X-CSRF-Token': token ? token.content : '' },
      body: body,
      credentials: 'same-origin'
    }).then(function(response) {
      if (!response.ok) throw new Error(response.status);
      return response.json();
    }).then(function(data) {
      cells.forEach(function(cell) { cell.classList.toggle('no-work-week', data.flagged); });
    }).catch(function() {
      checkbox.checked = !checkbox.checked;
      alert(calendar.dataset.noWorkWeekError || 'Could not save the week');
    }).finally(function() {
      checkbox.disabled = false;
    });
  };
})();
