$(function() {

  tinymce.init({
    selector: '.editable',
    plugins: 'advlist autolink link image lists charmap print preview',
    inline: true,
    setup: function(ed) {
      ed.on('change', function() {
        $(".btn.save")
          .show();
      });
    }
  });

  $(".btn.save")
    .click(function(ev) {
      var $art = $("article");
      $.post("/save", {
          uuid: $art.attr("data-uuid"),
          text: $art.html(),
          title: $("h1")
            .text()
        })
        .done(function(ev) {
          $(".btn.save")
            .hide();
        });

    });

});
