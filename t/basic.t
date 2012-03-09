use Mojo::Base -strict;
use Mojolicious::Lite;
use Test::More tests => 3;
use Test::Mojo;

plugin 'ParamExpand';

get '/' => sub {
    my $self = shift;
    $self->render('expand', 
                  hash   => $self->req->url->query,
		  array  => $self->param('array'),
		  scalar => $self->param('scalar'));
};


my $qs = join '&', 'hash.a=a',
                   'hash.b.c=b',
                   'array.0=0',
                   'array.1.key=1',
                   'scalar=scalar';

my $t = Test::Mojo->new;
$t->get_ok("/?$qs")->status_is(200)->content_is('a,b|0,1|scalar');

__DATA__
@@ expanded.html.ep
<%= $hash->{a} %>,<%= $hash->{b}->{c} %>|<%= $array->[0] %>,<%= $array->[1]->{key} %>|<%= $scalar %>
