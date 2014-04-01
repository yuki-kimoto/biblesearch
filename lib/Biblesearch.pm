package Biblesearch;

our $VERSION = '0.01';

use Mojo::Base 'Mojolicious';
use DBIx::Custom;
use File::Path 'mkpath';
use Mojo::JSON;
use Mojo::Util 'spurt';

has 'dbi';

sub startup {
  my $self = shift;
  
  # Config
  $self->plugin('Config');
  
  # DBI
  my $db_file = $self->home->rel_file('db/bible.db');
  my $dbi = DBIx::Custom->connect(
    dsn =>  "dbi:SQLite:dbname=$db_file",
    option => {sqlite_unicode => 1},
    connector => 1
  );
  $self->dbi($dbi);
  
  # Models
  my $models = [
    {
      table => 'book',
      primary_key => 'id'
    },
    {
      table => 'section',
      primary_key => [qw/book_id chapter section/]
    }
  ];
  $dbi->create_model($_) for @$models;
  
  # Route
  my $r = $self->routes;
  $r->get('/')->to(template => 'index');
  $r->get('/about');
  $r->get('/api/book/:id/content.json')->to(cb => sub {
    my $self = shift;
    my $id = $self->param('id');
    
    my $dbi = $self->app->dbi;
    my $content = $dbi->model('book')->select('content', id => $id)->value;
    
    if ($content) {
      my $dir = $self->app->home->rel_file("public/api/book/$id");
      mkpath $dir;
      
      my $data = {
        content => $content
      };
      
      my $json = Mojo::JSON->new;
      my $data_json = $json->encode($data);
      spurt $data_json, $self->app->home->rel_file("public/api/book/$id/content.json");
      
      $self->render_static("/api/book/$id/content.json");
    }
    else {
      $self->render_not_found;
    }
  });
  
  $r->get('/api/word-count/:word')->to(cb => sub {
    my $self = shift;
    my $word = $self->param('word');
    my $dbi = $self->app->dbi;
    
    my $word_count_h = {};
    for (my $i = 0; $i < 66; $i++) {
      my $num = sprintf "%02d", $i + 1;
      
      my $content = $dbi->select(
        'content_no_tag',
        table => 'book',
        where => {id => $num}
      )->value;
      my $content_length = length $content;
      my $word_q = quotemeta($word);
      $content =~ s/$word_q//g;
      my $content_length_no_word = length $content;
      
      # 文字の個数
      my $word_count = ($content_length - $content_length_no_word) / length $word;
      $word_count_h->{$num} = $word_count;
    }
    
    $self->render(json => {word_count => $word_count_h});
  });
}

1;
