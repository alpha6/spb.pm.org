#!/usr/bin/env perl

use common::sense;
use Mojolicious::Lite;


get '/' => sub {
	my $self = shift;
	$self->render( template => 'index');
};

app->start;
