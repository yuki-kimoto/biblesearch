package Perltweet::API;
use Mojo::Base 'Mojolicious::Controller';
use utf8;

has 'cntl';

sub app { shift->cntl->app }

1;
