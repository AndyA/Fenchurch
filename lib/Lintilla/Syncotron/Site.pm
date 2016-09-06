package Lintilla::Syncotron::Site;

use v5.10;

use Dancer ':syntax';

use Lintilla::Adhocument::Versions;

our $VERSION = '0.1';

sub dbv {
}

get '/' => sub {
    template 'index';
};

prefix '/sync' => sub {
  get '/leaves/:start/:size' => sub {

  };

  get '/t' => sub {
    return \@INC;
  };
};

true;
