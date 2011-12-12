#!/usr/bin/env perl

use common::sense;
use Mojolicious::Lite;
use Digest::SHA1  qw(sha1_hex);
use UUID::Tiny;

use MongoDB;

my $config = plugin 'Config';

plugin recaptcha => {
   public_key  => $config->{recaptcha}{public_key},
   private_key => $config->{recaptcha}{private_key},
   lang        => 'ru'
};

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
    my $user = $users->find_one({
        login  => $login,
        passwd => sha1_hex($passwd)
    });
    if ($user->{'login'}) {
        my $sid = create_UUID_as_string(UUID_V4);
        my $agent = $self->req->headers->user_agent || 'Empty';
        $session->insert({
            sid      => $sid,
            sign     => $agent,
            user     => $user->{'login'},
            last_act => time
        });
        $self->session(sid => $sid);
        $self->redirect_to('/');
    } else {
        $self->flash(login_error => 'Не верный пароль');
        $self->redirect_to('/login');
    }
};

get '/logout' => sub { $_[0]->session(expires => 1); $_[0]->redirect_to('/'); };

# get '/register' => sub {
#     my $self = shift;
#
#     $self->render(
#         message  => 'Поля "логин" и "пароль" обязательны',
#         template => 'register'
#     );
# };

post '/register' => sub {
    my $self = shift;

    $self->recaptcha;
    if ($self->stash('recaptcha_error')) {
        $self->flash(warning => 'Неверно введён текст капчи');

        return $self->redirect_to('/register');
    }
    my $login  = $self->req->param('login');
    my $passwd = $self->req->param('passwd');
    my $email  = $self->req->param('email');

    unless ($login && $passwd) {
        $self->flash(warning => 'Пожалуйста, введите логин и пароль');

        return $self->redirect_to('/register');
    }
    my $user = $users->find_one({ login => $login });
    if ($user) {
	$self->flash(warning => 'Данный логин уже занят');
        $self->redirect_to('/register');
    }
    else {
        $users->insert({
            login    => $login,
            passwd   => sha1_hex($passwd),
            email    => $email,
            reg_date => time,
        });
        $self->redirect_to('/login');
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
    my $users = join "\n", map {$_->{'login'}} @all;
    $self->render(text => "<pre>$users</pre>");
};

app->secret($config->{secret});
app->start;

