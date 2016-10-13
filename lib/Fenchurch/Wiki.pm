package Fenchurch::Wiki;

use Dancer ':syntax';
use Dancer::Plugin::Database;

# ABSTRACT: A Wiki to test Fenchurch versioning, sync.

our $VERSION = '0.01';

use Fenchurch::Adhocument::Versions;
use Fenchurch::Core::DB;
use Fenchurch::Syncotron::HTTP::Server;
use Fenchurch::Wiki::Engine;
use Fenchurch::Wiki::Schema;

sub get_versions {
  my $dbh = database;

  my $schema = Fenchurch::Wiki::Schema->new( dbh => $dbh );

  my $versions = Fenchurch::Adhocument::Versions->new(
    schema => $schema->schema,
    db     => $schema->db
  );

  return $versions;
}

sub get_engine {
  return Fenchurch::Wiki::Engine->new( versions => get_versions() );
}

post '/sync' => sub {
  return Fenchurch::Syncotron::HTTP::Server->new(
    versions => get_versions )->handle_raw( request->body );
};

post '/save' => sub {
  return get_engine()->save( {params} );
};

post '/delete' => sub {
  return get_engine()->delete( param('uuid') );
};

get '/random' => sub {
  my $pages = get_engine()->page_list;
  my $pick  = rand( scalar @$pages );
  redirect '/' . $pages->[$pick]{slug};
};

get '/:slug' => sub {
  my $eng = get_engine();
  template 'index',
   {stash => $eng->page( param('slug') ),
    pages => $eng->page_list
   };
};

get '/' => sub {
  redirect "/home";
};

true;
