$(document).ready(function() {
  var $dialog = $('#new-customer-dialog');
  var customerFormXHR = null;

  // 1. Initialize jQuery UI Dialog (built into Redmine)
  $dialog.dialog({
    autoOpen: false,
    modal: true,
    width: 500,
    title: "New Customer",
    buttons: {
      "Save": function() {
        submitInlineCustomer();
      },
      "Cancel": function() {
        $(this).dialog("close");
      }
    },
    close: function() {
      // Abort in-flight request if closing before load finishes
      if (customerFormXHR) {
        customerFormXHR.abort();
      }
      // Force hide Redmine's global loading overlay
      $('#ajax-indicator').hide();
      // Reset modal contents
      $dialog.empty();
    }
  });

  // 2. Open Modal & Fetch Form
  $('#inline-create-customer-btn').on('click', function(e) {
    e.preventDefault();

    // Explicitly grab value by the appointment field's specific ID
    var typedName = $('#customer_appointment_customer').val();

    $dialog.dialog('open');

    // Fetch form bypassing Redmine's global ajax-indicator
    customerFormXHR = $.ajax({
      url: '/customers/new',
      type: 'GET',
      global: false,
      success: function(data) {
        $dialog.html(data);

        // Hide standalone submit button and wiki toolbar inside modal
        $dialog.find('.actions, .jstBlock').hide();

        // Copy typed name into the modal's specific customer_name field
        if (typedName && typedName.trim() !== '') {
          $dialog.find('#customer_name').val(typedName.trim());
        }

        // Handle ENTER key submission inside modal form
        $dialog.find('form').off('submit').on('submit', function(ev) {
          ev.preventDefault();
          submitInlineCustomer();
        });
      },
      error: function(xhr, status) {
        if (status !== 'abort') {
          $dialog.html('<p style="color: red; padding: 10px;">Failed to load customer form.</p>');
        }
      }
    });
  });

  // 3. Submit Customer Form via AJAX
  function submitInlineCustomer() {
    var $form = $dialog.find('form');
    if ($form.length === 0) return;

    $.ajax({
      url: $form.attr('action'),
      type: 'POST',
      data: $form.serialize(),
      dataType: 'json',
      global: false,
      success: function(response) {
        // Populate main appointment form fields with newly created customer details
        $('#customer_id').val(response.id);
        $('#customer_appointment_customer').val(response.name);

        // Reset dependent select dropdowns for new customer
        $('#appointment_vehicle_id').empty().append('<option value=""></option>');
        $('#appointment_estimate_id').empty().append('<option value=""></option>');

        // Close and clean up modal
        $dialog.dialog('close');
      },
      error: function(xhr) {
        var errors = (xhr.responseJSON && xhr.responseJSON.errors) 
          ? xhr.responseJSON.errors 
          : ['Failed to create customer'];
        alert("Errors:\n" + errors.join("\n"));
      }
    });
  }

  // 4. Dismiss Redmine's global loader when selecting from autocomplete
  $(document).on('autocompleteselect', '.customer-name', function(event, ui) {
    $('#ajax-indicator').hide();
  });
});