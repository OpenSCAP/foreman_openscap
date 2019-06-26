function readFromCookie() {
  try {
    var r = $.cookie(cookieName);
    if (r) {
      return $.parseJSON(r);
    }
    return [];
  } catch (err) {
    removeCookie();
    return [];
  }
}

function removeCookie() {
  $.removeCookie(cookieName);
}

var cookieName = '_ForemanSelected' + window.location.pathname.replace(/\//, '');

function buildArfModal(element, url) {
  var url = url + "?" + $.param({arf_report_ids: readFromCookie()});
  var title = $(element).attr('data-dialog-title');
  $('#confirmation-modal .modal-header h4').text(title);
  $("#confirmation-modal .modal-body").load(url + " #content",
      function(response, status, xhr) {
        $('#submit_multiple').val('');
        var b = $("#confirmation-modal .btn-primary");
        if ($(response).find('#content form select').length > 0)
          b.addClass("disabled").attr("disabled", true);
        else
          b.removeClass("disabled").attr("disabled", false);
        $('#confirmation-modal').modal();
        });
  return false;
}
