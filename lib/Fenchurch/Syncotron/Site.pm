package Fenchurch::Syncotron::Site;

our $VERSION = "1.00";

use v5.10;

use Dancer ':syntax';

use Fenchurch::Adhocument::Versions;

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
