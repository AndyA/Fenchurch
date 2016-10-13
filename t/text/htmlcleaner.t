#!perl -w

use v5.10;

use strict;

use Test::More;
use Test::Differences;

use Text::HTMLCleaner;

my @tc = (
  { name => "Passthrough",
    html => "Hello, World",
    text => "Hello, World"
  },
  { name => "Strip link",
    html => 'Go to <a href="foo.html">foo</a> now',
    text => 'Go to foo now'
  },
  { name => "Line break",
    html => 'Line One<br>Line Two',
    text => "Line One\nLine Two"
  },
  { name => "Strip script, noscript",
    html => <<EOT,
The Man with the Flower in his Mouth
<script>
  require(['smp'], function(SMP) {
    new SMP({
      "container": "#smp-14369224835188",
      "pid": "p02d2sm7",
      "playerSettings": {
        "delayEmbed": true,
        "externalEmbedUrl": "http:\/\/www.bbc.co.uk\/programmes\/p02d2sm7\/player"
      }
    });
  });
</script>
<noscript>You must enable javascript to play content</noscript>
A re-creation of the television play
EOT
    text =>
     'The Man with the Flower in his Mouth  A re-creation of the television play'
  },
  { name => "Strip fancy quotes",
    html =>
     " '&hellip;' '&ldquo;' '&rdquo;' '&lsquo;' '&rsquo;' '&ndash;' '&mdash;' ",
    text  => "'\x{2026}' '\x{201c}' '\x{201d}' '\x{2018}' '\x{2019}' '\x{2013}' '\x{2014}'",
    plain => "'...' '\"' '\"' ''' ''' '-' '-'"
  }
);

for my $tc (@tc) {
  my $args = $tc->{args} // [];
  my $cleaner = Text::HTMLCleaner->new( html => $tc->{html}, @$args );
  eq_or_diff $cleaner->text, $tc->{text}, "$tc->{name}: text matches";
  eq_or_diff $cleaner->plain, $tc->{plain} // $tc->{text},
   "$tc->{name}: plain matches";
}

done_testing;
