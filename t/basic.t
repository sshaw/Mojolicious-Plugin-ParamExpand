use Mojo::Base -strict;
use Mojolicious::Lite;
use Test::More tests => 9;
use Test::Mojo;

sub qs { join '&', @_ }

my $qs;
my $t = Test::Mojo->new;

get '/params_are_expanded';
get '/flattened_params_still_exist';

plugin 'ParamExpand';

$qs = qs 'hash.a=a',
         'hash.b.c=b',
         'array.0=0',
         'array.1=1',
         'scalar=scalar';		

$t->get_ok("/params_are_expanded?$qs")
    ->status_is(200)
    ->content_like(qr/\Qa,b|0,1|scalar/);

$t->get_ok("/flattened_params_still_exist?$qs")
    ->status_is(200)
    ->content_like(qr/\Qa,b|0,1/);
   
plugin 'ParamExpand', separator => ',';

$qs = qs 'hash,a=a',
    	 'hash,b,c=b',
	 'array,0=0',
         'array,1=1',
         'scalar=scalar';

$t->get_ok("/params_are_expanded?$qs")
    ->status_is(200)
    ->content_like(qr/\Qa,b|0,1/);

__DATA__
@@ params_are_expanded.html.ep
<% my @a = param('array'); %>
<%= param('hash')->{a} %>,<%= param('hash')->{b}->{c} %>|<%= $a[0] %>,<%= $a[1] %>|<%= param('scalar') %>

@@ flattened_params_still_exist.html.ep
<%= param('hash.a') %>,<%= param('hash.b.c') %>|<%= param('array.0') %>,<%= param('array.1') %>
