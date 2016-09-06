package Fenchurch::Syncotron::Site;

use v5.10;

use Dancer ':syntax';

use Fenchurch::Adhocument::Versions;

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
