function initCustomerAppointmentForm() {
  const customerIdInput = document.getElementById('customer_id');
  if (!customerIdInput) return;

  let lastValue = customerIdInput.value;

  // Watch for changes via value attribute modification or standard change events
  const observer = new MutationObserver(checkValueChange);
  observer.observe(customerIdInput, { attributes: true, attributeFilter: ['value'] });

  customerIdInput.addEventListener('change', checkValueChange);

  function checkValueChange() {
    const customerId = customerIdInput.value;
    if (customerId === lastValue) return;
    lastValue = customerId;

    // The lists that depend on the customer: the estimates, and other plugins' (select[data-customer-option])
    document.querySelectorAll('select[data-customer-option]').forEach(select => clearSelect(select.id));
    if (!customerId) return;

    fetch(`/customer_appointments/customer_options?customer_id=${customerId}`)
      .then(response => response.json())
      .then(data => {
        Object.entries(data.options || {}).forEach(([selectId, items]) => populateSelect(selectId, items));
      })
      .catch(err => console.error('Failed to load customer options:', err));
  }

  function populateSelect(elementId, items) {
    const select = document.getElementById(elementId);
    if (!select) return;

    select.innerHTML = '<option value=""></option>';
    items.forEach(item => {
      const option = document.createElement('option');
      option.value = item.id;
      option.textContent = item.name;
      select.appendChild(option);
    });
  }

  function clearSelect(elementId) {
    const select = document.getElementById(elementId);
    if (select) select.innerHTML = '<option value=""></option>';
  }
}

// Initialize on DOM load
document.addEventListener('DOMContentLoaded', initCustomerAppointmentForm);