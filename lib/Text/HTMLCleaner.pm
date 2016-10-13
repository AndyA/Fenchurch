package Text::HTMLCleaner;

use utf8;

use Moose;

use HTML::Parser;

=head1 NAME

Text::HTMLCleaner - Strip formatting from HTML

=cut

has html => ( is => 'ro', isa => 'Str', required => 1 );

# The names of tags to strip
has strip => (
  is       => 'ro',
  isa      => 'ArrayRef',
  required => 1,
  default  => sub {
    ["script", "noscript"];
  },
);

has translate => (
  is       => 'ro',
  isa      => 'HashRef',
  required => 1,
  default  => sub {
    { '…' => '...',
      '“' => '"',
      '”' => '"',
      '‘' => "'",
      '’' => "'",
      '–' => "-",
      '—' => "-"
    };
  },
);

has text => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  builder => '_build_text'
);

has plain => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  builder => '_build_plain'
);

sub _build_text {
  my $self = shift;

  my $html  = $self->html;
  my %strip = map { $_ => 1 } @{ $self->strip };
  my $skip  = 0;

  $html =~ s/^\s+//s;
  $html =~ s/\s+$//s;

  my $p   = HTML::Parser->new;
  my @txt = ();
  $p->handler(
    text => sub {
      return if $skip;
      my $txt = shift;
      $txt =~ s/^\n//s;
      $txt =~ s/\n$//s;
      $txt =~ s/\n/ /msg;
      push @txt, $txt;
    },
    'dtext'
  );

  $p->handler(
    start => sub {
      my $tag = shift;
      $skip++ if $strip{$tag};
      return  if $skip;
      push @txt, "\n" if $tag eq 'br' || $tag eq 'div';
      push @txt, "\n\n" if $tag eq 'p';
    },
    'tagname'
  );

  $p->handler(
    end => sub {
      my $tag = shift;
      if ( $strip{$tag} ) {
        $skip--;
        push @txt, " " if $skip == 0;
      }
    },
    'tagname'
  );

  $p->parse($html);
  $p->eof;
  my $txt = join '', @txt;
  $txt =~ s/\xa0/ /g;
  return $txt;
}

sub _build_plain {
  my $self    = shift;
  my $xl      = $self->translate;
  my $xl_from = join "", map quotemeta, keys %$xl;
  return join "", map { $xl->{$_} // $_ } split /([$xl_from])/,
   $self->text;
}

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
