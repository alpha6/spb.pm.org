#!/usr/bin/env perl

use common::sense;
use Mojolicious::Lite;
use Digest::SHA1  qw(sha1_hex);
use UUID::Tiny;

use MongoDB;
use MongoDB::OID;

use Data::Dumper;

my $db = MongoDB::Connection->new->spbpm;

my $users   = $db->users;
my $session = $db->sessions;
my $news    = $db->news;

my $session_life = 60*60*24;

under sub {
    my $self = shift;
    my $sid = $self->session('sid');
    if ($sid) {
        my $agent = $self->req->headers->user_agent || 'Empty';
        my $user = $session->find_one({ sid => $sid, sign => $agent });
        if ($user->{'last_act'} < (time - $session_life)) {
            $self->stash(user_data => { is_auth => 0 });
        }
        else {
            $user->{'is_auth'} = 1;
            delete($user->{'passwd'});
            $self->stash(user_data => $user);
        }
    }
    else {
        $self->stash(user_data => { is_auth => 0 });
    }

    1;
};

get '/' => sub {
	my $self = shift;

	$self->render(template => 'index');
};

get '/login' => sub {
    my $self = shift;
    
    $self->render(template => 'login');
};

post '/login' => sub {
    my $self = shift;

    my $login  = $self->req->param('login');
    my $passwd = $self->req->param('passwd');
    my $user = $users->find_one({ login => $login, passwd => sha1_hex($passwd) });
    if ($user->{'login'}) {
        my $sid = create_UUID_as_string(UUID_V4);
        my $agent = $self->req->headers->user_agent || 'Empty';
        $session->insert({ sid => $sid, sign => $agent, user => $user->{'login'}, last_act => time});
        $self->session(sid => $sid);
        $self->redirect_to('/');
    } else {
        $self->render(login_error => '<h4 class=error>Не правильный пароль</h4>', template => 'login');
    }
};

get '/register' => sub {
    my $self = shift;

    $self->stash(message => 'Login and password are mandatory');
    $self->render(template => 'register');
};

post '/register' => sub {
    my $self = shift;

    my $login  = $self->req->param('login');
    my $passwd = $self->req->param('passwd');
    my $email  = $self->req->param('email');
    if (!($login && $passwd)) {
        $self->stash(message => 'Please provide login and password');
        $self->render(template => 'register');
    }
    else {
        my $user = $users->find_one({ login => $login });
        if ($user) {
            $self->stash(message => 'This login is no longer available');
            $self->render(template => 'register');
        }
        else {
            $users->insert({
                login    => $login,
                passwd   => sha1_hex($passwd),
                email    => $email,
                reg_date => time,
            });
            $self->render(template => 'login');
        }
    }
};

get '/add/news' => sub {
    my $self = shift;

    $self->render(template => 'add_news');
};

post '/add/news' => sub {
    my $self = shift;
};

get '/users' => sub {
    my $self = shift;

    my @all = $users->find->sort({reg_date => 1})->all;
    $self->render(text => "<pre>".Dumper(@all)."</pre>");
};

app->secret('Perl mongers of Saint-Petersburg');
app->start;

